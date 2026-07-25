# frozen_string_literal: true

require_relative "denotation"
require_relative "relation_validator"

class SimpleInlineTextAnnotation
  class Generator
    include DenotationValidator
    include RelationValidator

    def initialize(source)
      @source = source.dup.freeze
      @denotations = build_denotations(source["denotations"] || [])
      @config = @source["config"]
    end

    def generate
      text = @source["text"]
      raise SimpleInlineTextAnnotation::GeneratorError, 'The "text" key is missing.' if text.nil?

      denotations = validate_denotations(@denotations, text.length)
      relations = validate_relations(@source["relations"] || [])

      annotated_text = annotate_text(text, denotations, relations)
      label_definitions = build_label_definitions

      [annotated_text, label_definitions].compact.join("\n\n")
    end

    private

    def build_denotations(denotations)
      denotations.map { |d| Denotation.new(d["span"]["begin"], d["span"]["end"], d["obj"], d["id"]) }
    end

    def annotate_text(text, denotations, relations)
      # Group denotations by span position so multiple denotations on the
      # SAME span emit ONE annotation with a pipe-joined label
      # (e.g. `[eye][UBERON_0000019|UBERON_0000955]`) — the SIAF spec's
      # extension for multi-labelled spans. Individual URL resolution via
      # `entity types` config still applies to each label independently, so
      # the tail reference block lists every underlying URL.
      grouped = denotations.group_by { |d| [d.begin_pos, d.end_pos] }

      # Annotate text from the end to ensure position calculation.
      grouped.sort_by { |(b, _e), _| b }.reverse_each do |(_b, _e), ds|
        text = annotate_text_with_denotations(text, ds, relations)
      end

      text
    end

    def annotate_text_with_denotations(text, denotations, relations)
      begin_pos = denotations.first.begin_pos
      end_pos   = denotations.first.end_pos
      composite = compose_label(denotations, relations)

      annotated_text = "[#{text[begin_pos...end_pos]}][#{composite}]"
      text[0...begin_pos] + annotated_text + text[end_pos..]
    end

    # Compose each denotation's label independently (honors get_obj URL →
    # short-label lookup and per-denotation relation composition), then
    # pipe-join with dedupe to preserve insertion order.
    def compose_label(denotations, relations)
      denotations.map { |d| label_for(d, relations) }.uniq.join("|")
    end

    def label_for(denotation, relations)
      if denotation.id && !denotation.id.empty?
        get_annotations(denotation, relations)
      else
        get_obj(denotation.obj)
      end
    end

    def labeled_entity_types
      return nil unless @config

      @config["entity types"]&.select { |entity_type| entity_type.key?("label") }
    end

    def get_annotations(denotation, relations)
      relation = relations.find { |rel| rel["subj"] == denotation.id }
      annotations = [denotation.id, denotation.obj, relation&.dig("pred"), relation&.dig("obj")]

      return annotations.compact.join(", ") unless labeled_entity_types

      annotations[1] = get_obj(denotation.obj)
      annotations.compact.join(", ")
    end

    def get_obj(obj)
      return obj unless labeled_entity_types

      entity = labeled_entity_types.find { |entity_type| entity_type["id"] == obj }
      entity ? entity["label"] : obj
    end

    def build_label_definitions
      return nil if labeled_entity_types.nil? || labeled_entity_types.empty?

      labeled_entity_types.map do |entity|
        "[#{entity["label"]}]: #{entity["id"]}"
      end.join("\n")
    end
  end
end
