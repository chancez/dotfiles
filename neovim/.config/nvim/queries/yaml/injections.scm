; extends

; Inject JSON into block scalar strings that appear to contain JSON
((block_scalar) @injection.content
  (#lua-match? @injection.content "^[|>].-\n%s*[%{%[]")
  (#set! injection.language "json")
  (#offset! @injection.content 1 0 0 0))

; Inject JSON into double-quoted strings that appear to contain JSON
((double_quote_scalar) @injection.content
  (#lua-match? @injection.content "^\"%s*[%{%[]")
  (#set! injection.language "json")
  (#offset! @injection.content 0 1 0 -1))

; Inject JSON into single-quoted strings that appear to contain JSON
((single_quote_scalar) @injection.content
  (#lua-match? @injection.content "^'%s*[%{%[]")
  (#set! injection.language "json")
  (#offset! @injection.content 0 1 0 -1))

; No yaml in yaml injections because values are indented and would require more
; complex parsing to determine the correct indentation level for the injected
; content.
