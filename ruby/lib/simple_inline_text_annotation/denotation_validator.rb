# frozen_string_literal: true

class SimpleInlineTextAnnotation
  module DenotationValidator
    def validate_denotations(denotations, text_length)
      result = remove_duplicates_from(denotations)
      result = remove_non_integer_positions_from(result)
      result = remove_negative_positions_from(result)
      result = remove_invalid_positions_from(result)
      result = remove_out_of_bound_positions_from(result, text_length)
      result = remove_nests_from(result)
      remove_boundary_crosses_from(result)
    end

    private

    def remove_duplicates_from(denotations)
      # Deduplicate on the FULL identity (span + obj + id), not just span —
      # two denotations sharing a span but pointing at different objs are the
      # multi-label case (e.g. `[eye][UBERON_0000019|UBERON_0000955]`) and
      # Generator pipe-joins them. Only truly identical entries are dropped.
      denotations.uniq { |d| [ d.span, d.obj, d.id ] }
    end

    def remove_non_integer_positions_from(denotations)
      denotations.reject(&:position_not_integer?)
    end

    def remove_negative_positions_from(denotations)
      denotations.reject(&:position_negative?)
    end

    def remove_invalid_positions_from(denotations)
      denotations.reject(&:position_invalid?)
    end

    def remove_out_of_bound_positions_from(denotations, text_length)
      denotations.reject { |denotation| denotation.out_of_bounds?(text_length) }
    end

    def remove_nests_from(denotations)
      # Sort by begin_pos in ascending order. If begin_pos is the same, sort by end_pos in descending order.
      sorted_denotations = denotations.sort_by { |d| [d.begin_pos, -d.end_pos] }
      result = []

      sorted_denotations.each do |denotation|
        # Preserve denotations that share an EXACT span with an already-accepted
        # one (the multi-label case — Generator will pipe-join their labels).
        # Only drop those STRICTLY nested inside a larger outer span.
        result << denotation unless result.any? { |outer| strictly_nested?(denotation, outer) }
      end

      result
    end

    def strictly_nested?(inner, outer)
      inner.nested_within?(outer) && (inner.begin_pos != outer.begin_pos || inner.end_pos != outer.end_pos)
    end

    def remove_boundary_crosses_from(denotations)
      denotations.reject do |denotation|
        denotations.any? { |existing| denotation.boundary_crossing?(existing) }
      end
    end
  end
end
