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

; Inject YAML into block scalar strings that appear to contain YAML mappings
((block_scalar) @injection.content
  (#lua-match? @injection.content "^[|>].-\n%s*%w[%w_%-%.]*:%s")
  (#not-lua-match? @injection.content "^[|>].-\n%s*[%{%[]")
  (#set! injection.language "yaml")
  (#offset! @injection.content 1 0 0 0))

; Inject YAML into block scalar strings that appear to contain YAML sequences
((block_scalar) @injection.content
  (#lua-match? @injection.content "^[|>].-\n%s*%- ")
  (#not-lua-match? @injection.content "^[|>].-\n%s*[%{%[]")
  (#set! injection.language "yaml")
  (#offset! @injection.content 1 0 0 0))
