# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleInlineTextAnnotation::Generator, type: :model do
  describe "#generate" do
    subject { SimpleInlineTextAnnotation.generate(source) }

    context "when source has denotations" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
          ]
        }
      end
      let(:expected_format) do
        "[Elon Musk][Person] is a member of the [PayPal Mafia][Organization]."
      end

      it "generate annotation structure" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source has config" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 9 }, "obj" => "https://example.com/Person" },
            { "span" => { "begin" => 29, "end" => 41 }, "obj" => "https://example.com/Organization" }
          ],
          "config" => {
            "entity types" => [
              { "id" => "https://example.com/Person", "label" => "Person" },
              { "id" => "https://example.com/Organization", "label" => "Organization" }
            ]
          }
        }
      end
      let(:expected_format) do
        <<~MD2.chomp
          [Elon Musk][Person] is a member of the [PayPal Mafia][Organization].

          [Person]: https://example.com/Person
          [Organization]: https://example.com/Organization
        MD2
      end

      it "generate label definition structure" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source has denotations with ids but no relations" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
          ]
        }
      end
      let(:expected_format) do
        "[Elon Musk][T1, Person] is a member of the [PayPal Mafia][T2, Organization]."
      end

      it "displays ids in annotations even without relations" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source has denotations and relations" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
          ],
          "relations" => [
            { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
          ]
        }
      end
      let(:expected_format) do
        "[Elon Musk][T1, Person, member_of, T2] is a member of the " \
          "[PayPal Mafia][T2, Organization]."
      end

      it "generate annotation structure" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source includes entity config and relations" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "https://example.com/Person" },
            { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "https://example.com/Organization" }
          ],
          "relations" => [
            { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
          ],
          "config" => {
            "entity types" => [
              { "id" => "https://example.com/Person", "label" => "Person" },
              { "id" => "https://example.com/Organization", "label" => "Organization" }
            ]
          }
        }
      end
      let(:expected_format) do
        <<~MD2.chomp
          [Elon Musk][T1, Person, member_of, T2] is a member of the [PayPal Mafia][T2, Organization].

          [Person]: https://example.com/Person
          [Organization]: https://example.com/Organization
        MD2
      end

      it "generate label definition structure" do
        is_expected.to eq(expected_format)
      end
    end

    context "when entity type has present but label is missing" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" }
          ],
          "relations" => [
            { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
          ],
          "config" => {
            "entity types" => [
              { "id" => "Person" }
            ]
          }
        }
      end

      let(:expected_format) { "[Elon Musk][T1, Person, member_of, T2] is a member of the PayPal Mafia." }

      it "should create only annotation structure" do
        is_expected.to eq(expected_format)
      end
    end

    context "when denotation is missing" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => []
        }
      end
      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "does not generate any denotation" do
        is_expected.to eq(expected_format)
      end
    end

    context "when span value is not integer" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 0.1, "end" => 9.6 }, "obj" => "Person" }
          ]
        }
      end

      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "should not parse as annotation" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source has same span denotations" do
      # Prior to v2.2, only the first denotation on a shared span was kept.
      # v2.2 introduces the multi-label extension: same-span denotations are
      # pipe-joined into one annotation. See the dedicated multi-label context
      # below for URL-resolution + dedupe interactions.
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Organization" }
          ]
        }
      end
      let(:expected_format) { "[Elon Musk][Person|Organization] is a member of the PayPal Mafia." }

      it "pipe-joins labels on the shared span" do
        is_expected.to eq(expected_format)
      end
    end

    context "when source has nested span within another span" do
      context "when both begin and end are inside" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [
              { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
              { "span" => { "begin" => 2, "end" => 6 }, "obj" => "Organization" }
            ]
          }
        end
        let(:expected_format) { "[Elon Musk][Person] is a member of the PayPal Mafia." }

        it "should use only outer denotation" do
          is_expected.to eq(expected_format)
        end
      end

      context "when begin is inside" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [
              { "span" => { "begin" => 0, "end" => 4 }, "obj" => "First name" },
              { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Full name" }
            ]
          }
        end
        let(:expected_format) { "[Elon Musk][Full name] is a member of the PayPal Mafia." }

        it "should use only outer denotation" do
          is_expected.to eq(expected_format)
        end
      end

      context "when end is inside" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [
              { "span" => { "begin" => 6, "end" => 9 }, "obj" => "Last name" },
              { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Full name" }
            ]
          }
        end
        let(:expected_format) { "[Elon Musk][Full name] is a member of the PayPal Mafia." }

        it "should use only outer denotation" do
          is_expected.to eq(expected_format)
        end
      end
    end

    context "when source has boundary-crossing denotations" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
            { "span" => { "begin" => 8, "end" => 11 }, "obj" => "Organization" }
          ]
        }
      end
      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "should be both ignored" do
        is_expected.to eq(expected_format)
      end
    end

    context "when denotations span is negative" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => -1, "end" => 9 }, "obj" => "Person" }
          ]
        }
      end
      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "should be ignored" do
        is_expected.to eq(expected_format)
      end
    end

    context "when denotations span is invalid" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 4, "end" => 0 }, "obj" => "Person" }
          ]
        }
      end
      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "should be ignored" do
        is_expected.to eq(expected_format)
      end
    end

    context "when denotation is out of bound with text length" do
      let(:source) do
        {
          "text" => "Elon Musk is a member of the PayPal Mafia.",
          "denotations" => [
            { "span" => { "begin" => 100, "end" => 200 }, "obj" => "Person" }
          ]
        }
      end
      let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

      it "should be ignored" do
        is_expected.to eq(expected_format)
      end
    end

    context "with relation" do
      context "when subject is invalid and relation exists" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [
              { "id" => "T1", "span" => { "begin" => 0.1, "end" => 9.6 }, "obj" => "Person" }
            ],
            "relations" => [
              { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
            ]
          }
        end

        let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

        it "ignores the invalid denotation and its relation" do
          is_expected.to eq(expected_format)
        end
      end

      context "when subject does not exist" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [
              { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
            ],
            "relations" => [
              { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
            ]
          }
        end
        let(:expected_format) { "Elon Musk is a member of the [PayPal Mafia][T2, Organization]." }

        it "does not generate the relation due to subject does not exist" do
          is_expected.to eq(expected_format)
        end
      end

      context "when both subject and object do not exist" do
        let(:source) do
          {
            "text" => "Elon Musk is a member of the PayPal Mafia.",
            "denotations" => [],
            "relations" => [
              { "subj" => "T1", "pred" => "member_of", "obj" => "T2" }
            ]
          }
        end
        let(:expected_format) { "Elon Musk is a member of the PayPal Mafia." }

        it "does not generate the relation because both subject and object do not exist" do
          is_expected.to eq(expected_format)
        end
      end

      context "when relation keys are missing" do
        context "when subj is missing" do
          let(:source) do
            {
              "text" => "Elon Musk is a member of the PayPal Mafia.",
              "denotations" => [
                { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
              ],
              "relations" => [
                { "pred" => "member_of", "obj" => "T2" }
              ]
            }
          end
          let(:expected_format) { "[Elon Musk][T1, Person] is a member of the [PayPal Mafia][T2, Organization]." }

          it "does not generate the relation" do
            is_expected.to eq(expected_format)
          end
        end

        context "when pred is missing" do
          let(:source) do
            {
              "text" => "Elon Musk is a member of the PayPal Mafia.",
              "denotations" => [
                { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" },
                { "id" => "T2", "span" => { "begin" => 29, "end" => 41 }, "obj" => "Organization" }
              ],
              "relations" => [
                { "subj" => "T1", "obj" => "T2" }
              ]
            }
          end
          let(:expected_format) { "[Elon Musk][T1, Person] is a member of the [PayPal Mafia][T2, Organization]." }

          it "does not generate the relation" do
            is_expected.to eq(expected_format)
          end
        end

        context "when obj is missing" do
          let(:source) do
            {
              "text" => "Elon Musk is a member of the PayPal Mafia.",
              "denotations" => [
                { "id" => "T1", "span" => { "begin" => 0, "end" => 9 }, "obj" => "Person" }
              ],
              "relations" => [
                { "subj" => "T1", "pred" => "member_of" }
              ]
            }
          end
          let(:expected_format) { "[Elon Musk][T1, Person] is a member of the PayPal Mafia." }

          it "does not generate the relation" do
            is_expected.to eq(expected_format)
          end
        end
      end
    end

    context "when source text key is missing" do
      let(:source) do
        {
          "denotations" => [
            { "span" => { "begin" => 4, "end" => 0 }, "obj" => "Person" }
          ]
        }
      end

      it "raises GeneratorError" do
        expect { subject }.to raise_error(SimpleInlineTextAnnotation::GeneratorError, 'The "text" key is missing.')
      end
    end

    # ------------------------------------------------------------------
    # Extension (v2.2): multiple labels on the same span → pipe-joined.
    # ------------------------------------------------------------------
    context "when multiple denotations share the same span (multi-label)" do
      let(:source) do
        {
          "text" => "eye",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "UBERON_0000019" },
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "UBERON_0000955" }
          ]
        }
      end

      it "pipe-joins the labels into a single annotation preserving insertion order" do
        is_expected.to eq("[eye][UBERON_0000019|UBERON_0000955]")
      end
    end

    context "when multiple denotations share the same span AND identify by URL with entity_types" do
      # Combines pipe-join with URL resolution: each obj resolves to its
      # short label, joined labels appear inline, and the reference block
      # lists every URL individually.
      let(:source) do
        {
          "text" => "eye",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "http://x/UBERON_0000019" },
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "http://x/UBERON_0000955" }
          ],
          "config" => {
            "entity types" => [
              { "id" => "http://x/UBERON_0000019", "label" => "UBERON_0000019" },
              { "id" => "http://x/UBERON_0000955", "label" => "UBERON_0000955" }
            ]
          }
        }
      end

      it "resolves each URL to its label independently, then pipe-joins" do
        expected = <<~SIAF.chomp
          [eye][UBERON_0000019|UBERON_0000955]

          [UBERON_0000019]: http://x/UBERON_0000019
          [UBERON_0000955]: http://x/UBERON_0000955
        SIAF
        is_expected.to eq(expected)
      end
    end

    context "when two same-span denotations point at the SAME obj (pathological)" do
      # Deduplicate within the pipe list — collapse identical entries so
      # we don't emit `[eye][A|A]`.
      let(:source) do
        {
          "text" => "eye",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "A" },
            { "span" => { "begin" => 0, "end" => 3 }, "obj" => "A" }
          ]
        }
      end

      it "deduplicates identical labels within a single annotation" do
        is_expected.to eq("[eye][A]")
      end
    end

    context "when three or more denotations share the same span" do
      # 2-label ordering is trivially symmetric; 3+ catches a subtle regression
      # where a stray `.sort` would put labels in alphabetic order instead of
      # insertion order.
      let(:source) do
        {
          "text" => "T-cell",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 6 }, "obj" => "Beta" },
            { "span" => { "begin" => 0, "end" => 6 }, "obj" => "Alpha" },
            { "span" => { "begin" => 0, "end" => 6 }, "obj" => "Gamma" }
          ]
        }
      end

      it "preserves insertion order in the pipe list (not alphabetic)" do
        is_expected.to eq("[T-cell][Beta|Alpha|Gamma]")
      end
    end

    context "when a multi-label span AND a strictly-nested inner span coexist" do
      # Composed behavior: same-span duplicates merge (pipe-joined), while a
      # separate span strictly nested inside them is dropped. Guards against
      # accidental interaction between `remove_duplicates_from`,
      # `remove_nests_from`, and Generator's grouping.
      let(:source) do
        {
          "text" => "optic nerve xyz",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 11 }, "obj" => "A" },
            { "span" => { "begin" => 0, "end" => 11 }, "obj" => "B" },
            { "span" => { "begin" => 6, "end" => 11 }, "obj" => "INNER" }
          ]
        }
      end

      it "pipe-joins the outer multi-label span and drops the strictly-nested inner" do
        is_expected.to eq("[optic nerve][A|B] xyz")
      end
    end

    context "when a smaller span is strictly nested inside a same-begin larger span" do
      # 'optic nerve' [0-11] contains 'optic' [0-5] with a shared begin_pos.
      # Historically the validator dropped both (nested_within? was inclusive);
      # the fix distinguishes STRICT nesting from an identical span, so the
      # outer is kept and the strictly-nested inner is dropped.
      let(:source) do
        {
          "text" => "optic nerve xyz",
          "denotations" => [
            { "span" => { "begin" => 0, "end" => 11 }, "obj" => "OUTER" },
            { "span" => { "begin" => 0, "end" => 5 },  "obj" => "INNER" }
          ]
        }
      end

      it "keeps the outer span and drops the strictly-nested inner" do
        is_expected.to eq("[optic nerve][OUTER] xyz")
      end
    end
  end
end
