# Simple Inline Annotation Format (SIAF)

It is a lightweight and intuitive solution for text annotation.
Its syntax aligns seamlessly with Markdown conventions, ensuring compatibility with existing Markdown editors and general text editors,
making annotations easy to create, edit, and maintain.

## Why Use it?
- **LLM-Friendly**: Eliminates the need for LLMs to calculate precise character offsets, a task where models frequently struggle. Instead, the model simply wraps the target text in-place.
- **Markdown Native**: Works seamlessly in your existing documentation workflow without breaking rendering or syntax highlighting.
- **Maintainable**: Because the annotation lives with the content, editing the text doesn't "break" a separate index or JSON map of coordinates.

## Syntax Rules

1. Annotation Structure

   * An annotation is represented by two consecutive pairs of square brackets:

     * The first pair contains the annotated text.

     * The second pair contains the label.

   * Example: \[Annotated Text\]\[Label\]

   * It aligns with Markdown's syntax for reference-style links.

2. Metacharacter Escaping

   * The annotation structure (two consecutive pairs of square brackets) is unlikely to appear in normal text but is not entirely impossible. If it does occur, it may be misinterpreted as an annotation. To avoid this, the first opening square bracket must be escaped with a backslash (\\).

   * Example: \\\[This is a part of\]\[original text\]


## Example

| Format | Annotation |
| :---- | :---- |
| Inline | \[Elon Musk\]\[Person\] is a member of the \[PayPal Mafia\]\[Organization\]. |
| JSON | {“denotations”:\[{“span”:{“begin”: 0, “end”: 9}, “obj”:”Person”},    {“span”:{“begin”: 29, “end”: 41}, “obj”:”Organization”}\]} |

## Tools

Because the syntax is lightweight and follows standard conventions, you can create and manage annotations in any basic text editor (like Notepad or TextEdit) or advanced Markdown editors (like Obsidian or VS Code) without specialized plugins.

For more rigorous annotation tasks, the format can be read in with [TextAE](https://textae.pubannotation.org), allowing users to visualize and edit inline tags through a robust, web-based graphical interface.


## Conversion

- [PubAnnotation](https://pubannotation.org) provides APIs for conversion between the inline and JSON formats (https://www.pubannotation.org/docs/simple-inline-annotation-format).
- [Ruby gem](https://rubygems.org/gems/simple_inline_text_annotation)
