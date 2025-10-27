; extensions

; Injects JSON into Go string literals that are detected to contain JSON content.
(raw_string_literal
  (raw_string_literal_content) @injection.content
  (#match? @injection.content "^[ \t\n]*\\{[ \t\n]*\".*\"[ \t\n]*:")
  (#set! injection.language "json")
)
