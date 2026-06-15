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
    arg_list = 'argument_list',

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

-- Open a write site and land on the source value (or the field for `x++`).
local function goto_write_site(site)
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  vim.lsp.util.show_document({ uri = site.uri, range = site.range }, enc, { focus = true })
  if site.land then
    vim.api.nvim_win_set_cursor(0, { site.land.row + 1, site.land.col })
  end
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
      }, goto_write_site, on_done)
    end
  end

  -- Fallback: not a parameter, field, or func name -> plain go-to-definition.
  vim.lsp.buf.definition()
  on_done(true)
end

-- Repeat trace_up `count` times, but stop early at any branch point or origin.
function M.trace_up_n(count)
  count = math.max(count or 1, 1)
  local function step(remaining)
    if remaining <= 0 then return end
    M.trace_up(function(moved)
      if moved then
        -- defer so LSP/treesitter state for the new buffer is settled
        vim.schedule(function() step(remaining - 1) end)
      end
    end)
  end
  step(count)
end

return M
