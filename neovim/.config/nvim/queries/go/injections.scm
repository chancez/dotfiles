;; extends

; Injects JSON into Go string literals that are detected to contain JSON content.
(raw_string_literal
  (raw_string_literal_content) @injection.content
  (#match? @injection.content "^[ \t\n]*\\{[ \t\n]*\".*\"[ \t\n]*:")
  (#set! injection.language "json")
)

; Injects SQL into Go raw string literals that start with SQL keywords.
(raw_string_literal
  (raw_string_literal_content) @injection.content
  (#match? @injection.content "^[ \t\n]*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|WITH|MERGE|TRUNCATE|REPLACE|GRANT|REVOKE)")
  (#set! injection.language "sql")
)
