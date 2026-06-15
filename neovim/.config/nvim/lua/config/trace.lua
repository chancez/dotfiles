-- Trace a value back toward its origin, one hop "up" the call stack at a time.
--
-- A single repeatable motion that dispatches on what is under the cursor:
--   * function/method declaration name -> its call sites (jump to caller; does
--     not chain, since there is no single value to keep following)
--   * function parameter -> the matching argument expression at each call site
--   * struct field -> the places the field is written, landing on the source value
--   * anything else -> plain LSP go-to-definition
--
-- The design is a hybrid: LSP answers the semantic questions (definition, who
-- calls this, where is this referenced) and treesitter handles the syntactic
-- landings LSP cannot express (parameter index, the Nth argument at a call site,
-- classifying a reference as a write). See the langs table for the per-language
-- node names; adding a language is mostly filling in another entry there.
--
-- Throughout, a hop with one destination jumps silently so it can be chained
-- (trace_up_n), while multiple destinations prompt and stop at that branch.

local M = {}

-- Per-language treesitter node names.
local langs = {
  go = {
    func_decl = { function_declaration = true, method_declaration = true },
    param_list = 'parameter_list',
    param_decl = { parameter_declaration = true, variadic_parameter_declaration = true },
    variadic_decl = { variadic_parameter_declaration = true },
    call_expr = 'call_expression',
    call_func_field = 'function',
    selector_expr = 'selector_expression',
    selector_field = 'field',
    arg_list = 'argument_list',

    -- Following a value back through a local declaration into the callee's
    -- return (the "trace into the function, args emerge from the param logic"
    -- step). A declared name's value comes from the matching value expression;
    -- when that value is a call, we descend into the callee's return.
    short_var_decl = 'short_var_declaration',  -- a, b := x, y    (left/right)
    var_spec = 'var_spec',                     -- var a, b = x, y (name.../value)
    var_spec_name = 'name',
    var_spec_value = 'value',
    return_stmt = 'return_statement',
    func_literal = 'func_literal',             -- pruned when scanning returns
    func_body = 'body',
    -- Unwrap a leading unary operator so we land on the operand, not the symbol:
    -- `&T{...}` lands on the composite literal, `*p` lands on p.
    unary_expr = 'unary_expression',
    unary_operand = 'operand',
    -- For a composite literal `T{...}` / `pkg.T{...}`, land on the type name so
    -- the next hop reaches the type definition rather than the package.
    composite_literal = 'composite_literal',
    composite_type = 'type',
    qualified_type = 'qualified_type',
    qualified_name = 'name',

    -- Field-write tracing. We use LSP references to find every use of a field,
    -- then treesitter (these node names) to keep only the writes.
    -- A node names a field if it is one of these types ...
    field_ref = { field_identifier = true },
    -- ... unless it is the `name` of one of these (method/func names reuse the
    -- field_identifier type but are not field references).
    field_ref_exclude_parent = { method_declaration = true, function_declaration = true },
    -- A plain identifier is a field ref only when it is the key of a struct
    -- literal element (e.g. `S{field: x}`).
    composite_key_ref = { identifier = true },

    -- Write classification.
    assignment = 'assignment_statement',  -- covers `=` and compound `+=` etc.
    assign_left = 'left',
    assign_right = 'right',
    expr_list = 'expression_list',
    inc_dec = { inc_statement = true, dec_statement = true },
    keyed_element = 'keyed_element',
    keyed_key = 'key',
    keyed_value = 'value',
  },
}

local function cfg_for_buf(bufnr)
  return langs[vim.bo[bufnr].filetype]
end

-- Walk up from `node` to the nearest ancestor whose type is a key in `types`.
local function find_ancestor(node, types)
  while node do
    if types[node:type()] then
      return node
    end
    node = node:parent()
  end
end

local function nodes_equal(a, b)
  if not (a and b) then return false end
  local ar, ac = a:start()
  local br, bc = b:start()
  return ar == br and ac == bc and a:type() == b:type()
end

-- Named children of a node, as a list.
local function named_children(node)
  local out = {}
  for child in node:iter_children() do
    if child:named() then
      table.insert(out, child)
    end
  end
  return out
end

-- 1-based index of `target` among the named children of `node`, or nil.
local function index_in_named(node, target)
  local i = 0
  for child in node:iter_children() do
    if child:named() then
      i = i + 1
      if nodes_equal(child, target) then
        return i
      end
    end
  end
  return nil
end

-- 1-based index of the named child of `parent` that is, or contains, `node`.
local function child_index_containing(parent, node)
  local i = 0
  for child in parent:iter_children() do
    if child:named() then
      i = i + 1
      if nodes_equal(child, node) or vim.treesitter.is_ancestor(child, node) then
        return i
      end
    end
  end
  return nil
end

-- If the cursor sits on a parameter in a function signature, return its flat
-- index (0-based, counting individual names) and whether it is variadic.
-- Returns nil if the cursor is not on a parameter.
local function param_under_cursor(cfg)
  local node = vim.treesitter.get_node()
  if not node then return nil end

  local pdecl = find_ancestor(node, cfg.param_decl)
  if not pdecl then return nil end
  local plist = pdecl:parent()
  if not plist or plist:type() ~= cfg.param_list then return nil end

  -- The identifier the cursor is actually on (for multi-name params).
  local cursor_id = node
  while cursor_id and cursor_id:type() ~= 'identifier' do
    cursor_id = cursor_id:parent()
    if cursor_id and nodes_equal(cursor_id, pdecl) then
      cursor_id = nil
      break
    end
  end

  local idx = 0
  for child in plist:iter_children() do
    if cfg.param_decl[child:type()] then
      local variadic = cfg.variadic_decl[child:type()] or false
      local names = child:field('name')
      if #names == 0 then
        -- unnamed parameter occupies one slot
        if nodes_equal(child, pdecl) then
          return idx, variadic
        end
        idx = idx + 1
      else
        for _, nm in ipairs(names) do
          if nodes_equal(child, pdecl) and (not cursor_id or nodes_equal(nm, cursor_id)) then
            return idx, variadic
          end
          idx = idx + 1
        end
      end
    end
  end
  return nil
end

-- If the cursor is on the *name* of a function/method declaration, return that
-- name node's start position (for call hierarchy). Returns nil otherwise.
local function func_name_decl_under_cursor(cfg)
  local node = vim.treesitter.get_node()
  if not node then return nil end
  local decl = find_ancestor(node, cfg.func_decl)
  if not decl then return nil end
  local name = decl:field('name')[1]
  if not name then return nil end
  -- Cursor must actually be on the name, not elsewhere in the signature/body.
  if not (nodes_equal(name, node) or vim.treesitter.is_ancestor(name, node)) then
    return nil
  end
  local row, col = name:start()
  return { line = row, character = col }
end

-- Start position of the enclosing function's *name*, for call hierarchy.
local function enclosing_func_name_pos(cfg)
  local node = find_ancestor(vim.treesitter.get_node(), cfg.func_decl)
  if not node then return nil end
  local name = node:field('name')[1]
  if not name then return nil end -- anonymous func literal: no call hierarchy
  local row, col = name:start()
  return { line = row, character = col }
end

-- Collect call sites of the function whose name is at `pos` via call hierarchy.
-- Returns a list of { uri = string, range = lsp.Range }.
local function incoming_call_sites(bufnr, pos)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = pos,
  }
  local prepared = vim.lsp.buf_request_sync(bufnr, 'textDocument/prepareCallHierarchy', params, 2000)
  if not prepared then return {} end

  local sites = {}
  for _, resp in pairs(prepared) do
    for _, item in ipairs(resp.result or {}) do
      local client = vim.lsp.get_client_by_id(resp.client_id or 0)
      local calls = vim.lsp.buf_request_sync(bufnr, 'callHierarchy/incomingCalls', { item = item }, 2000)
      for _, cresp in pairs(calls or {}) do
        for _, call in ipairs(cresp.result or {}) do
          for _, range in ipairs(call.fromRanges or {}) do
            table.insert(sites, { uri = call.from.uri, range = range, client = client })
          end
        end
      end
    end
  end
  return sites
end

-- Given a freshly-focused buffer and an LSP range for a call, move the cursor
-- onto the `index`-th argument (0-based). Variadic params land on the first
-- variadic argument. Returns true on success.
local function jump_to_argument(cfg, index, variadic)
  local node = vim.treesitter.get_node()
  local call = find_ancestor(node, { [cfg.call_expr] = true })
  if not call then return false end
  local args = call:field('arguments')[1]
  if not args or args:type() ~= cfg.arg_list then return false end

  local named = {}
  for child in args:iter_children() do
    if child:named() then
      table.insert(named, child)
    end
  end

  local target = named[index + 1]
  if not target and variadic and #named > 0 then
    target = named[#named]
  end
  if not target then
    -- No matching arg (e.g. variadic with zero args); leave cursor on the call.
    return true
  end

  local row, col = target:start()
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  return true
end

-- Open a call site in the current window. With an argument index, land on that
-- argument; with index nil, just land on the call itself (function-name case).
local function goto_call_site(site, index, variadic)
  local offset_encoding = site.client and site.client.offset_encoding or 'utf-16'
  vim.lsp.util.show_document(
    { uri = site.uri, range = site.range },
    offset_encoding,
    { focus = true }
  )
  if index == nil then
    return
  end
  -- show_document put us on the call; treesitter is now available on this buffer.
  local cfg = cfg_for_buf(vim.api.nvim_get_current_buf())
  if cfg then
    jump_to_argument(cfg, index, variadic)
  end
end

-- ----------------------------------------------------------------------------
-- Field-write tracing.
--
-- "Go to definition" on a struct field lands you on the field declaration, which
-- is a dead end. To trace where the field's value comes from we want the places
-- the field is *written*. LSP references finds every use cross-file; treesitter
-- then keeps only the writes and points us at the assigned value.
-- ----------------------------------------------------------------------------

-- If the cursor is on a field name (a use `s.field` or the field declaration),
-- return that treesitter node. Returns nil otherwise. Method/function names
-- reuse the field_identifier node type, so we exclude those: declaration names
-- (handled by the func-name case) and method calls like `s.method()` (which
-- should go to the method definition, like a plain function usage).
local function field_under_cursor(cfg)
  local node = vim.treesitter.get_node()
  if not node then return nil end
  if not cfg.field_ref[node:type()] then return nil end

  local parent = node:parent()
  if not parent then return node end

  -- A declaration name (e.g. the method name in `func (s S) method()`).
  if cfg.field_ref_exclude_parent[parent:type()] then
    return nil
  end

  -- A method call `s.method()`: the field sits in a selector_expression that is
  -- the function being called. Let it fall through to go-to-definition.
  if parent:type() == cfg.selector_expr then
    local call = parent:parent()
    if call and call:type() == cfg.call_expr then
      local fn = call:field(cfg.call_func_field)[1]
      if fn and nodes_equal(fn, parent) then
        return nil
      end
    end
  end

  return node
end

-- Convert an LSP (utf-16 by default) character offset to a byte column.
local function byte_col(bufnr, row, character, encoding)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line then return character end
  local ok, col = pcall(vim.str_byteindex, line, encoding or 'utf-16', character, false)
  return ok and col or character
end

-- Given the treesitter node at a field reference, decide whether it is a write.
-- Returns nil for reads, otherwise a treesitter node to land on (the source
-- value expression), or false to mean "a write with no source" (e.g. `x++`).
local function classify_field_write(cfg, ref)
  -- struct literal key: S{field: <value>}
  local keyed = find_ancestor(ref, { [cfg.keyed_element] = true })
  if keyed then
    local key = keyed:field(cfg.keyed_key)[1]
    if key and (nodes_equal(key, ref) or vim.treesitter.is_ancestor(key, ref)) then
      return keyed:field(cfg.keyed_value)[1] or false
    end
  end

  -- assignment: s.field = <value>  or compound  s.field += <value>
  local assign = find_ancestor(ref, { [cfg.assignment] = true })
  if assign then
    local left = assign:field(cfg.assign_left)[1]
    if left and (nodes_equal(left, ref) or vim.treesitter.is_ancestor(left, ref)) then
      -- Find the direct LHS element (e.g. the selector_expression) holding ref,
      -- so multi-assign `a.x, b.y = 1, 2` maps to the right value slot.
      local target
      for child in left:iter_children() do
        if child:named() and (nodes_equal(child, ref) or vim.treesitter.is_ancestor(child, ref)) then
          target = child
          break
        end
      end
      local idx = target and index_in_named(left, target) or 1
      local right = assign:field(cfg.assign_right)[1]
      if not right then return false end
      return named_children(right)[idx] or right
    end
  end

  -- s.field++ / s.field-- : a write, but there is no source expression.
  if find_ancestor(ref, cfg.inc_dec) then
    return false
  end

  return nil
end

-- Find every write to the field whose name is at `pos`, via LSP references +
-- treesitter classification. Returns a list of
--   { uri, range, client, land = { row, col } }  (land is 0-based)
local function field_write_sites(bufnr, pos)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = pos,
    context = { includeDeclaration = false },
  }
  local resps = vim.lsp.buf_request_sync(bufnr, 'textDocument/references', params, 2000)
  if not resps then return {} end

  local sites = {}
  local seen = {}
  for _, resp in pairs(resps) do
    local client = vim.lsp.get_client_by_id(resp.client_id or 0)
    local enc = client and client.offset_encoding or 'utf-16'
    for _, loc in ipairs(resp.result or {}) do
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetRange
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true

        local b = vim.fn.bufadd(vim.uri_to_fname(uri))
        vim.fn.bufload(b)
        local cfg = cfg_for_buf(b)
        if cfg then
          local row = range.start.line
          local col = byte_col(b, row, range.start.character, enc)
          local ref = vim.treesitter.get_node({ bufnr = b, pos = { row, col } })
          if ref then
            local value = classify_field_write(cfg, ref)
            if value ~= nil then
              local land = { row = row, col = col }
              if value then
                local vr, vc = value:start()
                land = { row = vr, col = vc }
              end
              table.insert(sites, { uri = uri, range = range, client = client, land = land })
            end
          end
        end
      end
    end
  end
  return sites
end

-- Open a site and land on its `land` position (the source value): used for
-- field writes and for values followed through a declaration.
local function goto_landing_site(site)
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  vim.lsp.util.show_document({ uri = site.uri, range = site.range }, enc, { focus = true })
  if site.land then
    vim.api.nvim_win_set_cursor(0, { site.land.row + 1, site.land.col })
  end
end

-- Definition sites for the symbol at (row, col) (0-based, col in bytes) in
-- `bufnr`, via a synchronous LSP request so the jump happens before we report
-- completion (the quickfix trail depends on this; the built-in async
-- vim.lsp.buf.definition would let us record a stale position). A symbol can
-- resolve to several definitions (interfaces, etc). Used both for the cursor
-- fallback and for descending into a callee while following a value.
local function lsp_definition_at(bufnr, row, col)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/definition' })
  if #clients == 0 then return {} end
  local client = clients[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local character = col
  local ok, ch = pcall(vim.str_utfindex, line, client.offset_encoding, col)
  if ok then character = ch end
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = row, character = character },
  }
  local res = client:request_sync('textDocument/definition', params, 2000, bufnr)
  if not res or res.err or not res.result then return {} end

  local result = res.result
  -- Result may be a single Location/LocationLink or a list of them.
  if result.uri or result.targetUri then result = { result } end

  local sites, seen = {}, {}
  for _, loc in ipairs(result) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetSelectionRange or loc.targetRange
    if uri and range then
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true
        table.insert(sites, { uri = uri, range = range, client = client })
      end
    end
  end
  return sites
end

local function definition_sites(bufnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  return lsp_definition_at(bufnr, pos[1] - 1, pos[2])
end

-- Open a location and land at its start (used for the definition fallback).
local function goto_location(site)
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  vim.lsp.util.show_document({ uri = site.uri, range = site.range }, enc, { focus = true })
end

-- ----------------------------------------------------------------------------
-- Following a value back through a local declaration.
--
-- For `v := origin(a, b)` the source of v is not the arguments but the return
-- of origin: we trace *into* the callee and land on its return expression. When
-- that return expression is itself a parameter, the existing parameter case
-- takes over and walks back out to this very call site's matching argument. So
-- "which argument?" is never guessed; it falls out of the callee's dataflow.
--
-- Forks (multiple returns, multiple call sites, multiple definitions) all route
-- through the same picker-and-stop UX as everything else.
-- ----------------------------------------------------------------------------

-- An LSP range (in `encoding`) for a treesitter node in `bufnr`.
local function node_lsp_range(bufnr, node, encoding)
  local sr, sc, er, ec = node:range()
  local function pos(row, col)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
    local ch = col
    local ok, c = pcall(vim.str_utfindex, line, encoding or 'utf-16', col)
    if ok then ch = c end
    return { line = row, character = ch }
  end
  return { start = pos(sr, sc), ['end'] = pos(er, ec) }
end

-- Build a landing site (same shape as field-write sites) for a node in bufnr.
local function landing_site(bufnr, node, client)
  local row, col = node:start()
  local enc = client and client.offset_encoding or 'utf-16'
  return {
    uri = vim.uri_from_bufnr(bufnr),
    range = node_lsp_range(bufnr, node, enc),
    client = client,
    land = { row = row, col = col },
  }
end

-- Given `n_targets` assignment targets and the value expression list, return the
-- value feeding target `idx` (1-based): { value = node, result_index = N }.
-- Handles the multi-return case `v, err := f()` where one call feeds many names.
local function tuple_value(n_targets, value_list, idx)
  local vals = named_children(value_list)
  if #vals == n_targets then
    return { value = vals[idx], result_index = 1 }
  elseif #vals == 1 then
    -- One value (a call) spread across several names: keep the tuple position.
    return { value = vals[1], result_index = idx }
  end
  return { value = vals[idx] or vals[1], result_index = 1 }
end

-- If `node` is a name declared by a `:=` or `var` declaration, return
-- { value, result_index } describing where that name's value comes from.
-- Returns nil otherwise.
local function bound_value_for(cfg, node)
  if not node or node:type() ~= 'identifier' then return nil end

  local svd = find_ancestor(node, { [cfg.short_var_decl] = true })
  if svd then
    local left = svd:field(cfg.assign_left)[1]
    local right = svd:field(cfg.assign_right)[1]
    if left and right then
      local idx = child_index_containing(left, node)
      if idx then
        return tuple_value(#named_children(left), right, idx)
      end
    end
  end

  local vs = find_ancestor(node, { [cfg.var_spec] = true })
  if vs then
    local names = vs:field(cfg.var_spec_name)
    local value = vs:field(cfg.var_spec_value)[1]
    if value then
      for i, nm in ipairs(names) do
        if nodes_equal(nm, node) then
          return tuple_value(#names, value, i)
        end
      end
    end
  end
  return nil
end

-- If the cursor is on the name being declared in a `:=` or `var` declaration,
-- return { value, result_index } describing where that name's value comes from.
-- Returns nil otherwise.
local function var_decl_value_under_cursor(cfg)
  local node = vim.treesitter.get_node()
  return bound_value_for(cfg, node)
end

-- Return expressions for tuple position `result_index` across all return
-- statements directly in `func_node`'s body (nested function literals pruned,
-- since their returns belong to a different scope). Each result is
-- { node, result_index }: the expression and, if it is itself a call, the tuple
-- position to follow within it (preserved across `return f()` passthroughs).
local function return_expressions(cfg, func_node, result_index)
  local body = func_node:field(cfg.func_body)[1]
  if not body then return {} end
  local out = {}
  local function visit(node)
    local t = node:type()
    if t == cfg.func_literal then return end
    if t == cfg.return_stmt then
      local list
      for child in node:iter_children() do
        if child:named() and child:type() == cfg.expr_list then
          list = child
          break
        end
      end
      if list then
        local kids = named_children(list)
        if kids[result_index] then
          -- Distinct return expressions per result: pick this one, follow its
          -- first result if it is a call.
          table.insert(out, { node = kids[result_index], result_index = 1 })
        elseif #kids == 1 then
          -- `return f()` passing a (possibly multi-value) call straight through:
          -- keep looking for the same tuple position inside it.
          table.insert(out, { node = kids[1], result_index = result_index })
        end
      end
      return
    end
    for child in node:iter_children() do
      if child:named() then visit(child) end
    end
  end
  visit(body)
  return out
end

-- The function name node of a call (handles `pkg.Fn` / `recv.Method`).
local function call_name_node(cfg, call)
  local fn = call:field(cfg.call_func_field)[1]
  if not fn then return nil end
  if fn:type() == cfg.selector_expr then
    return fn:field(cfg.selector_field)[1] or fn
  end
  return fn
end

-- Produce landing sites for following `value` (the source of a declared name).
-- A call descends into the callee's return; if that return is itself a call we
-- keep descending (so `v := passthrough(...)` resolves through to the real
-- source, not the intermediate call). Anything else (identifier, literal, field
-- access) is landed on directly so the next hop continues the trace. The
-- visited set and depth cap guard against recursive/mutually-recursive calls.
--
-- A call we cannot descend into (interface method, stdlib or other body-less
-- definition, or one with no return at this position) falls back to landing on
-- the call expression itself. We never silently drop a branch: better to arrive
-- at the call and let the trace continue manually than to lose it.
local function value_sites(cfg, bufnr, value, result_index, visited, depth)
  visited = visited or {}
  depth = depth or 0

  -- Unwrap leading unary operators (`&T{...}`, `*p`) so we follow the operand
  -- rather than landing on the `&`/`*`.
  while value:type() == cfg.unary_expr do
    local operand = value:field(cfg.unary_operand)[1]
    if not operand then break end
    value = operand
  end

  local client = vim.lsp.get_clients({ bufnr = bufnr })[1]

  -- For a composite literal, land on the type name so the next hop reaches the
  -- type definition. With a qualified type `pkg.T`, use the `T` part, not `pkg`.
  if value:type() == cfg.composite_literal then
    local ty = value:field(cfg.composite_type)[1]
    if ty and ty:type() == cfg.qualified_type then
      ty = ty:field(cfg.qualified_name)[1] or ty
    end
    return { landing_site(bufnr, ty or value, client) }
  end

  if value:type() ~= cfg.call_expr then
    return { landing_site(bufnr, value, client) }
  end
  if depth > 25 then return { landing_site(bufnr, value, client) } end

  local name_node = call_name_node(cfg, value)
  if not name_node then return { landing_site(bufnr, value, client) } end
  local fr, fc = name_node:start()
  local defs = lsp_definition_at(bufnr, fr, fc)

  local sites = {}
  for _, def in ipairs(defs) do
    local b = vim.fn.bufadd(vim.uri_to_fname(def.uri))
    vim.fn.bufload(b)
    local dcfg = cfg_for_buf(b)
    if dcfg then
      local enc = def.client and def.client.offset_encoding or 'utf-16'
      local drow = def.range.start.line
      local dcol = byte_col(b, drow, def.range.start.character, enc)
      local dnode = vim.treesitter.get_node({ bufnr = b, pos = { drow, dcol } })
      -- The callee is either a named func/method declaration, or a variable
      -- bound to a function literal (a closure). Both have a body to descend.
      -- The definition points at the name being defined, so require that the
      -- name *is* the func decl's name (not merely nested inside some function,
      -- which would wrongly match the enclosing func of a closure assignment).
      local func
      if dnode then
        local decl = find_ancestor(dnode, dcfg.func_decl)
        local decl_name = decl and decl:field('name')[1]
        if decl_name and (nodes_equal(decl_name, dnode) or vim.treesitter.is_ancestor(decl_name, dnode)) then
          func = decl
        else
          local bound = bound_value_for(dcfg, dnode)
          if bound and bound.value and bound.value:type() == dcfg.func_literal then
            func = bound.value
          end
        end
      end
      if func then
        for _, ret in ipairs(return_expressions(dcfg, func, result_index)) do
          local sr, sc = ret.node:start()
          local key = string.format('%d:%d:%d', b, sr, sc)
          if not visited[key] then
            visited[key] = true
            vim.list_extend(sites,
              value_sites(dcfg, b, ret.node, ret.result_index, visited, depth + 1))
          end
        end
      end
    end
  end

  -- Could not descend (body-less definition, unresolved, or no return here):
  -- land on the call itself rather than dropping this branch.
  if #sites == 0 then
    return { landing_site(bufnr, value, client) }
  end
  return sites
end

-- A short, single-line description of a call site for the picker.
local function describe_site(site)
  local path = vim.uri_to_fname(site.uri)
  local rel = vim.fn.fnamemodify(path, ':~:.')
  local line = site.range.start.line
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  local text = (vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ''):gsub('^%s+', '')
  return string.format('%s:%d: %s', rel, line + 1, text)
end

-- Shared "land on a site" UX: zero sites stops with a message, one site jumps
-- silently (so chaining continues), many sites prompt (a branch point, so we
-- stop). `go(site)` performs the jump; `empty_msg` is shown when no sites exist.
local function resolve_sites(sites, opts, go, on_done)
  if #sites == 0 then
    vim.notify(opts.empty_msg, vim.log.levels.INFO)
    return on_done(false)
  end
  if #sites == 1 then
    go(sites[1])
    return on_done(opts.chains ~= false)
  end
  vim.ui.select(sites, { prompt = opts.prompt, format_item = describe_site }, function(choice)
    if choice then
      go(choice)
    end
    on_done(false)
  end)
end

-- One hop "up". Returns true if the cursor moved (so a caller can keep going),
-- false if we stopped (origin reached, ambiguous and prompting, or error).
-- `on_done(moved)` is called when the (possibly async) hop settles.
function M.trace_up(on_done)
  on_done = on_done or function() end
  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = cfg_for_buf(bufnr)

  if cfg then
    -- Cursor on a function/method declaration name -> its call sites. This is a
    -- "jump to caller", not value tracing: we land on the call itself and there
    -- is nothing to chain from, so it does not auto-continue.
    local fpos = func_name_decl_under_cursor(cfg)
    if fpos then
      local sites = incoming_call_sites(bufnr, fpos)
      return resolve_sites(sites, {
        prompt = 'Trace up to call site:',
        empty_msg = 'trace: no call sites found (origin?)',
        chains = false,
      }, function(site) goto_call_site(site, nil) end, on_done)
    end

    -- Cursor on a parameter -> jump to the matching call site argument.
    local index, variadic = param_under_cursor(cfg)
    if index ~= nil then
      local pos = enclosing_func_name_pos(cfg)
      if not pos then
        vim.notify('trace: cannot resolve enclosing function', vim.log.levels.WARN)
        return on_done(false)
      end
      local sites = incoming_call_sites(bufnr, pos)
      return resolve_sites(sites, {
        prompt = 'Trace up to call site:',
        empty_msg = 'trace: no call sites found (origin?)',
      }, function(site) goto_call_site(site, index, variadic) end, on_done)
    end

    -- Cursor on a struct field -> jump to where it is written.
    local field = field_under_cursor(cfg)
    if field then
      local row, col = field:start()
      local sites = field_write_sites(bufnr, { line = row, character = col })
      return resolve_sites(sites, {
        prompt = 'Trace up to field write:',
        empty_msg = 'trace: no writes to this field found',
      }, goto_landing_site, on_done)
    end

    -- Cursor on a name declared by `:=` or `var` -> follow its value. A call
    -- value descends into the callee's return (args emerge from the param case);
    -- any other value is landed on directly to continue the trace.
    local decl = var_decl_value_under_cursor(cfg)
    if decl and decl.value then
      local sites = value_sites(cfg, bufnr, decl.value, decl.result_index)
      return resolve_sites(sites, {
        prompt = 'Trace up to value source:',
        empty_msg = 'trace: no value source found',
      }, goto_landing_site, on_done)
    end
  end

  -- Fallback: not a parameter, field, or func name -> go-to-definition.
  local sites = definition_sites(bufnr)
  return resolve_sites(sites, {
    prompt = 'Trace up to definition:',
    empty_msg = 'trace: no definition found',
  }, goto_location, on_done)
end

-- Build a quickfix entry describing the current cursor position.
local function qf_entry_for_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  return {
    bufnr = vim.api.nvim_get_current_buf(),
    lnum = pos[1],
    col = pos[2] + 1,
    text = vim.trim(vim.api.nvim_get_current_line()),
  }
end

-- A comparable snapshot of the cursor location, to detect a hop that lands where
-- it started (e.g. go-to-definition on an identifier that is already its own
-- definition). Such a fixpoint is an origin, so the loop must stop there.
local function cursor_location()
  local pos = vim.api.nvim_win_get_cursor(0)
  return { buf = vim.api.nvim_get_current_buf(), row = pos[1], col = pos[2] }
end

local function same_location(a, b)
  return a and b and a.buf == b.buf and a.row == b.row and a.col == b.col
end

-- Repeat trace_up up to `count` times, stopping early at any branch point or
-- origin. opts:
--   quickfix (boolean)  when true, record the start position and every hop into
--                       a new quickfix list titled "Trace", opening it at the end.
function M.trace_up_n(count, opts)
  opts = opts or {}
  count = math.max(count or 1, 1)
  local record = opts.quickfix == true

  -- The trail: start position first, then each landing as we hop upward.
  local entries = {}
  if record then
    table.insert(entries, qf_entry_for_cursor())
  end

  local function flush()
    if not record then return end
    vim.fn.setqflist({}, ' ', { title = 'Trace', items = entries })
    if #entries > 1 then
      vim.cmd('copen')
    end
  end

  local function step(remaining)
    if remaining <= 0 then return flush() end
    local before = cursor_location()
    M.trace_up(function(moved)
      -- A hop that reports movement but left the cursor put has reached a
      -- fixpoint (its own definition): treat it as an origin and stop, without
      -- recording the duplicate.
      if not moved or same_location(before, cursor_location()) then
        return flush()
      end
      if record then
        table.insert(entries, qf_entry_for_cursor())
      end
      -- defer so LSP/treesitter state for the new buffer is settled
      vim.schedule(function() step(remaining - 1) end)
    end)
  end
  step(count)
end

return M
