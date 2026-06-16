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
    method_decl = 'method_declaration',
    receiver_field = 'receiver', -- the parameter_list holding a method receiver
    param_list = 'parameter_list',
    param_decl = { parameter_declaration = true, variadic_parameter_declaration = true },
    variadic_decl = { variadic_parameter_declaration = true },
    call_expr = 'call_expression',
    call_func_field = 'function',
    selector_expr = 'selector_expression',
    selector_field = 'field',
    selector_operand = 'operand',
    arg_list = 'argument_list',

    -- Following a value back through a local declaration into the callee's
    -- return (the "trace into the function, args emerge from the param logic"
    -- step). A declared name's value comes from the matching value expression;
    -- when that value is a call, we descend into the callee's return.
    short_var_decl = 'short_var_declaration', -- a, b := x, y    (left/right)
    var_spec = 'var_spec',                    -- var a, b = x, y (name.../value)
    var_spec_name = 'name',
    var_spec_value = 'value',
    return_stmt = 'return_statement',
    func_literal = 'func_literal', -- pruned when scanning returns
    func_body = 'body',
    -- Unwrap a leading unary operator so we land on the operand, not the symbol:
    -- `&T{...}` lands on the composite literal, `*p` lands on p.
    unary_expr = 'unary_expression',
    unary_operand = 'operand',
    -- For a composite literal `T{...}` / `pkg.T{...}`, land on the type name so
    -- the next hop reaches the type definition rather than the package.
    composite_literal = 'composite_literal',
    composite_type = 'type',
    composite_body = 'body',             -- composite_literal -> literal_value
    literal_value = 'literal_value',     -- contains keyed_element children
    literal_element = 'literal_element', -- wraps a keyed_element key/value
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
    assignment = 'assignment_statement', -- covers `=` and compound `+=` etc.
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

-- Configuration. Each key is backed by `vim.g.trace_<key>`, so it can be set
-- from anywhere (vimrc, :let, lua) and survives reloading this module; the
-- `defaults` table is the single source of truth for the keys and their
-- defaults. Read via field access -- `Config.lsp_timeout` returns
-- vim.g.trace_lsp_timeout or the default. No string keys at the call sites.
--
-- NOTE: defaults MUST live in a separate table, and `Config` itself MUST be
-- empty, because __index only fires for ABSENT keys. If the defaults were stored
-- directly in Config, every read would hit the stored value and vim.g would be
-- ignored entirely.
local defaults = {
  debug = false,           -- vim.g.trace_debug: log to :messages
  lsp_timeout = 2000,      -- vim.g.trace_lsp_timeout: per-LSP-request ms
  project_max_nodes = 200, -- vim.g.trace_project_max_nodes: projection fan-out cap
  project_max_depth = 25,  -- vim.g.trace_project_max_depth: projection recursion cap
}
local Config = setmetatable({}, {
  __index = function(_, key)
    local v = vim.g['trace_' .. key]
    if v == nil then return defaults[key] end
    return v
  end,
})

-- Debug logging, toggled with vim.g.trace_debug. Visible via :messages.
local function dbg(...)
  if not Config.debug then return end
  local parts = {}
  for _, v in ipairs({ ... }) do
    parts[#parts + 1] = type(v) == 'string' and v or vim.inspect(v)
  end
  vim.notify('[trace] ' .. table.concat(parts, ' '), vim.log.levels.INFO)
end

-- Inspect a synchronous LSP result, logging whether it timed out, errored, or
-- came back empty. `where` labels the call site. Returns the result unchanged.
local function check_lsp(where, res_or_resps, single)
  if not Config.debug then return res_or_resps end
  if single then
    -- client:request_sync result: { result = ..., err = ... } or nil (timeout).
    if res_or_resps == nil then
      dbg(where, 'TIMEOUT (nil result, gopls slow or not ready)')
    elseif res_or_resps.err then
      dbg(where, 'ERROR', res_or_resps.err)
    elseif not res_or_resps.result or vim.tbl_isempty(res_or_resps.result) then
      dbg(where, 'empty result (genuinely no answer)')
    end
  else
    -- buf_request_sync result: map of client_id -> { result=..., error=... } or nil.
    if res_or_resps == nil then
      dbg(where, 'TIMEOUT (nil, gopls slow or not ready)')
    else
      local any = false
      for _, r in pairs(res_or_resps) do
        if r.error then dbg(where, 'ERROR', r.error) end
        if r.result and not vim.tbl_isempty(r.result) then any = true end
      end
      if not any then dbg(where, 'empty result (genuinely no answer)') end
    end
  end
  return res_or_resps
end

-- ----------------------------------------------------------------------------
-- Async LSP via coroutines.
--
-- We reuse neovim's own async LSP (`buf_request_all`, the function that
-- `buf_request_sync` is itself built on -- same client_id->{err,result} result
-- map). A coroutine just bridges its callback back into straight-line code, so
-- the recursive tracing logic keeps its `local x = lsp(); use(x)` shape.
--
-- The request helpers are DUAL-MODE: inside a coroutine they run async (editor
-- stays responsive); outside one they fall back to the blocking sync call. So
-- the SAME code path serves the synchronous `gu`/`gU` and the async tree -- only
-- `trace_tree` runs its build inside a coroutine.
-- ----------------------------------------------------------------------------

-- Async buf_request_all, awaited: yields until all clients respond, returns the
-- same results map buf_request_sync would. Only valid inside a coroutine.
--
-- Crucially, buf_request_all (unlike buf_request_sync) has NO timeout: if no
-- client responds the handler never fires. That happens whenever the target
-- buffer has no client attached (common for background-loaded caller/definition
-- files). So we (a) short-circuit when there are no clients, and (b) guard with
-- a timeout that resumes with nil -- otherwise the coroutine hangs forever. A
-- `done` flag prevents the callback and the timeout from both resuming.
-- Per-coroutine completion callbacks (weak-keyed so dead coroutines are GC'd).
local co_done = setmetatable({}, { __mode = 'k' })

-- Resume a traced coroutine. When it finishes, its `done` callback runs on a
-- FRESH main-loop tick (vim.schedule), NOT inside the resume: window-modifying
-- ex-commands like `copen` are unreliable when executed inside a coroutine
-- resume driven from an LSP callback. Scheduling done sidesteps that entirely.
local function resume_co(co, ...)
  local ok, err = coroutine.resume(co, ...)
  if not ok then
    vim.notify('[trace] coroutine error: ' .. tostring(err), vim.log.levels.ERROR)
  end
  if coroutine.status(co) == 'dead' then
    local done = co_done[co]
    if done then
      co_done[co] = nil
      vim.schedule(done)
    end
  end
end

-- Async buf_request_all, awaited: yields until all clients respond, returns the
-- same results map buf_request_sync would. Only valid inside a coroutine.
--
-- Crucially, buf_request_all (unlike buf_request_sync) has NO timeout: if no
-- client responds the handler never fires. That happens whenever the target
-- buffer has no client attached (common for background-loaded caller/definition
-- files). So we (a) short-circuit when there are no clients, and (b) guard with
-- a timeout that resumes with nil -- otherwise the coroutine hangs forever. A
-- `done` flag prevents the callback and the timeout from both resuming.
local function await_buf_request(bufnr, method, params)
  local co = assert(coroutine.running(), 'await must run in a coroutine')

  -- Check for ANY attached client, not one filtered by `method`: the method
  -- filter can transiently report 0 even when a capable client is attached, and
  -- buf_request_all already routes only to capable clients (the timeout covers
  -- non-response). Filtering here caused false "no client" short-circuits.
  if #vim.lsp.get_clients({ bufnr = bufnr }) == 0 then
    dbg(string.format('await %s: no client on %s, skipping', method,
      vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t')))
    return nil
  end

  local resumed = false
  local function finish(results)
    if resumed then return end
    resumed = true
    resume_co(co, results)
  end

  vim.lsp.buf_request_all(bufnr, method, params, function(results)
    -- resume on the main loop, not inside the LSP callback context
    vim.schedule(function() finish(results) end)
  end)
  -- Timeout safety net (mirrors buf_request_sync): resume with nil if nothing
  -- comes back in time, so a slow/non-responding client cannot hang the trace.
  vim.defer_fn(function() finish(nil) end, Config.lsp_timeout)

  return coroutine.yield()
end

-- buf_request, dual-mode: async (awaited) inside a coroutine, sync otherwise.
local function lsp_buf_request(bufnr, method, params)
  if coroutine.isyieldable() then
    return await_buf_request(bufnr, method, params)
  end
  return vim.lsp.buf_request_sync(bufnr, method, params, Config.lsp_timeout)
end

-- Run `fn` either inside a fresh coroutine (when `async` is true) or directly.
-- The coroutine drives itself: the first resume runs until the first await's
-- yield, and each LSP callback resumes it, so `fn` runs to completion across
-- many event-loop ticks without blocking. `done()` is called (scheduled) when
-- fn returns, in both async and sync modes.
local function run_traced(async, fn, done)
  done = done or function() end
  if not async then
    fn()
    return done()
  end
  local co = coroutine.create(fn)
  co_done[co] = done
  resume_co(co)
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

-- The treesitter node text of a node in bufnr.
local function node_text(bufnr, node)
  return vim.treesitter.get_node_text(node, bufnr)
end

-- Convert an LSP (utf-16 by default) character offset to a byte column.
local function byte_col(bufnr, row, character, encoding)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line then return character end
  local ok, col = pcall(vim.str_byteindex, line, encoding or 'utf-16', character, false)
  return ok and col or character
end

-- Load the buffer for `uri` (or a path) in the background, returning its bufnr,
-- or nil if it can't be loaded. Guards against vim.fn.bufload errors (notably
-- E325 swap-file collisions when the file is open elsewhere): a single bad
-- buffer must not abort the whole trace. Swap is disabled for the load.
local function load_buf(uri)
  local path = uri:match('^%w+://') and vim.uri_to_fname(uri) or uri
  local b = vim.fn.bufadd(path)
  if not vim.api.nvim_buf_is_loaded(b) then
    local saved = vim.o.shortmess
    vim.bo[b].swapfile = false
    local ok = pcall(vim.fn.bufload, b)
    vim.o.shortmess = saved
    if not ok then
      dbg('load_buf failed (swap/other) for', path)
      return nil
    end
  end
  return b
end

-- Treesitter node at (row, col) (0-based) in `bufnr`. A buffer loaded in the
-- background (vim.fn.bufload) has its lines but no parsed treesitter tree, so a
-- plain vim.treesitter.get_node returns nil for it. We force a parse first, so
-- cross-file lookups (call sites, definitions in other files) work without the
-- buffer ever being displayed.
local function node_at(bufnr, row, col)
  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then return nil end
  parser:parse({ row, row + 1 })
  return vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
end

-- True if `plist` (a parameter_list) is a method's receiver list, not its
-- regular parameters. A receiver is NOT argument 0 at call sites: it's the
-- selector operand (`x` in `x.Method(...)`), so it must be handled separately.
local function is_receiver_list(cfg, plist)
  local parent = plist:parent()
  if not parent or parent:type() ~= cfg.method_decl then return false end
  local recv = parent:field(cfg.receiver_field)[1]
  return recv and nodes_equal(recv, plist) or false
end

-- If `node` is a method receiver, return its declaration node, else nil.
local function receiver_under_cursor(cfg, node)
  if not node then return nil end
  local pdecl = find_ancestor(node, cfg.param_decl)
  if not pdecl then return nil end
  local plist = pdecl:parent()
  if plist and plist:type() == cfg.param_list and is_receiver_list(cfg, plist) then
    return pdecl
  end
  return nil
end

-- If the cursor sits on a parameter in a function signature, return its flat
-- index (0-based, counting individual names) and whether it is variadic.
-- Returns nil if the cursor is not on a parameter (or is on a method receiver,
-- which is handled separately since it maps to the call's operand, not an arg).
local function param_under_cursor(cfg, node)
  if not node then return nil end

  local pdecl = find_ancestor(node, cfg.param_decl)
  if not pdecl then return nil end
  local plist = pdecl:parent()
  if not plist or plist:type() ~= cfg.param_list then return nil end
  if is_receiver_list(cfg, plist) then return nil end

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
local function func_name_decl_under_cursor(cfg, node)
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
local function enclosing_func_name_pos(cfg, node)
  node = find_ancestor(node, cfg.func_decl)
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
  local prepared = lsp_buf_request(bufnr, 'textDocument/prepareCallHierarchy', params)
  check_lsp('prepareCallHierarchy', prepared, false)
  if not prepared then return {} end

  local sites = {}
  for client_id, resp in pairs(prepared) do
    for _, item in ipairs(resp.result or {}) do
      local client = vim.lsp.get_client_by_id(resp.client_id or client_id or 0)
      local calls = lsp_buf_request(bufnr, 'callHierarchy/incomingCalls', { item = item })
      check_lsp('incomingCalls', calls, false)
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
-- Compute the 0-based { row, col } landing for argument `index` of the call at
-- `site` (an LSP location). Returns nil to mean "land on the call itself"
-- (function-name case, or no matching argument). Loads the buffer but does not
-- move the cursor, so it can be used while merely building data.
local function argument_land(site, index, variadic)
  if index == nil then return nil end
  local b = load_buf(site.uri)
  if not b then return nil end
  local cfg = cfg_for_buf(b)
  if not cfg then return nil end

  local enc = site.client and site.client.offset_encoding or 'utf-16'
  local row = site.range.start.line
  local col = byte_col(b, row, site.range.start.character, enc)
  local node = node_at(b, row, col)
  local call = node and find_ancestor(node, { [cfg.call_expr] = true })
  if not call then return nil end
  local args = call:field('arguments')[1]
  if not args or args:type() ~= cfg.arg_list then return nil end

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
  if not target then return nil end

  local r, c = target:start()
  return { row = r, col = c }
end

-- Like argument_land, but returns the argument's treesitter node along with its
-- buffer and cfg: { cfg, bufnr, node }. Used by projection to keep tracing into
-- the argument expression. Returns nil if no matching argument.
local function argument_node(site, index, variadic)
  if index == nil then return nil end
  local b = load_buf(site.uri)
  if not b then return nil end
  local cfg = cfg_for_buf(b)
  if not cfg then return nil end

  local enc = site.client and site.client.offset_encoding or 'utf-16'
  local row = site.range.start.line
  local col = byte_col(b, row, site.range.start.character, enc)
  local node = node_at(b, row, col)
  local call = node and find_ancestor(node, { [cfg.call_expr] = true })
  if not call then
    dbg(string.format('      argument_node @%d:%d node=%s -> no call_expression ancestor',
      row, col, node and node:type() or 'nil'))
    return nil
  end
  local args = call:field('arguments')[1]
  if not args or args:type() ~= cfg.arg_list then
    dbg('      argument_node: call has no argument_list')
    return nil
  end

  local named = {}
  for child in args:iter_children() do
    if child:named() then table.insert(named, child) end
  end
  local target = named[index + 1]
  if not target and variadic and #named > 0 then target = named[#named] end
  if not target then
    dbg(string.format('      argument_node: want index %d but call has %d args (%q)',
      index, #named, node_text(b, call):gsub('\n.*', '...')))
    return nil
  end
  return { cfg = cfg, bufnr = b, node = target }
end

-- For a method call `x.Method(...)` at `site`, return the receiver operand `x`
-- as { cfg, bufnr, node }. A method receiver maps to the call's selector
-- operand, NOT to argument 0 -- conflating them is what sent projection chasing
-- `ctx` into unrelated code. Returns nil if the call isn't a method call.
local function receiver_operand_node(site)
  local b = load_buf(site.uri)
  if not b then return nil end
  local cfg = cfg_for_buf(b)
  if not cfg then return nil end

  local enc = site.client and site.client.offset_encoding or 'utf-16'
  local row = site.range.start.line
  local col = byte_col(b, row, site.range.start.character, enc)
  local node = node_at(b, row, col)
  local call = node and find_ancestor(node, { [cfg.call_expr] = true })
  if not call then return nil end
  local fn = call:field(cfg.call_func_field)[1]
  if not fn or fn:type() ~= cfg.selector_expr then return nil end
  local operand = fn:field(cfg.selector_operand)[1]
  if not operand then return nil end
  return { cfg = cfg, bufnr = b, node = operand }
end

-- Open a site in the current window and land on `site.land` (0-based) if set,
-- else at the site's range start. The single jump primitive for all cases.
local function goto_site(site)
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  vim.lsp.util.show_document({ uri = site.uri, range = site.range }, enc, { focus = true })
  if site.land then
    vim.api.nvim_win_set_cursor(0, { site.land.row + 1, site.land.col })
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
local function field_under_cursor(cfg, node)
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
  local resps = lsp_buf_request(bufnr, 'textDocument/references', params)
  check_lsp('references (field-write)', resps, false)
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

        local b = load_buf(uri)
        local cfg = b and cfg_for_buf(b)
        if cfg then
          local row = range.start.line
          local col = byte_col(b, row, range.start.character, enc)
          local ref = node_at(b, row, col)
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
  local resps = lsp_buf_request(bufnr, 'textDocument/definition', params)
  check_lsp(string.format('definition @%d:%d', row, col), resps, false)
  if not resps then return {} end

  local sites, seen = {}, {}
  for client_id, resp in pairs(resps) do
    local c = vim.lsp.get_client_by_id(client_id) or client
    local result = resp.result
    if result then
      -- Result may be a single Location/LocationLink or a list of them.
      if result.uri or result.targetUri then result = { result } end
      for _, loc in ipairs(result) do
        local uri = loc.uri or loc.targetUri
        local range = loc.range or loc.targetSelectionRange or loc.targetRange
        if uri and range then
          local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
          if not seen[key] then
            seen[key] = true
            table.insert(sites, { uri = uri, range = range, client = c })
          end
        end
      end
    end
  end
  return sites
end

local function definition_sites(bufnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  return lsp_definition_at(bufnr, pos[1] - 1, pos[2])
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
local function var_decl_value_under_cursor(cfg, node)
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

-- Resolve the callee of `call` (via LSP definition) and return its return
-- expressions for tuple position `result_index`, as a list of
-- { cfg, bufnr, node, result_index }. Handles named funcs/methods and closures
-- (a variable bound to a func_literal). Shared by value_sites and projection.
local function callee_returns(cfg, bufnr, call, result_index)
  local name_node = call_name_node(cfg, call)
  if not name_node then return {} end
  local fr, fc = name_node:start()
  local defs = lsp_definition_at(bufnr, fr, fc)

  local out = {}
  for _, def in ipairs(defs) do
    local b = load_buf(def.uri)
    local dcfg = b and cfg_for_buf(b)
    if dcfg then
      local enc = def.client and def.client.offset_encoding or 'utf-16'
      local drow = def.range.start.line
      local dcol = byte_col(b, drow, def.range.start.character, enc)
      local dnode = node_at(b, drow, dcol)
      -- Named func/method declaration, or a variable bound to a func_literal.
      -- Require the definition node to BE the func decl's name (not merely
      -- nested inside some function, which would wrongly match a closure's
      -- enclosing function).
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
          table.insert(out, { cfg = dcfg, bufnr = b, node = ret.node, result_index = ret.result_index })
        end
      end
    end
  end
  return out
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

  -- For a field read `x.field`, land on the field rather than the operand, so
  -- the next hop traces where that field is written (the field-write case)
  -- rather than where the containing value came from. The field is almost
  -- always what you want here; a package-qualified name (`pkg.Name`) has the
  -- same syntax but falls through to the field-write case, which reports "no
  -- writes" -- itself a useful signal.
  if value:type() == cfg.selector_expr then
    local field = value:field(cfg.selector_field)[1]
    return { landing_site(bufnr, field or value, client) }
  end

  if value:type() ~= cfg.call_expr then
    return { landing_site(bufnr, value, client) }
  end
  if depth > 25 then return { landing_site(bufnr, value, client) } end

  local sites = {}
  for _, ret in ipairs(callee_returns(cfg, bufnr, value, result_index)) do
    local sr, sc = ret.node:start()
    local key = string.format('%d:%d:%d', ret.bufnr, sr, sc)
    if not visited[key] then
      visited[key] = true
      vim.list_extend(sites,
        value_sites(ret.cfg, ret.bufnr, ret.node, ret.result_index, visited, depth + 1))
    end
  end

  -- Could not descend (body-less definition, unresolved, or no return here):
  -- land on the call itself rather than dropping this branch.
  if #sites == 0 then
    return { landing_site(bufnr, value, client) }
  end
  return sites
end

-- ----------------------------------------------------------------------------
-- Projection: precise, scope-based field tracing.
--
-- A projection is a list of field names (the part after the dots in `x.A.B`).
-- We trace the *container* (which the LSP scopes to a specific variable) and
-- *apply* the projection only when we reach a concrete struct, so we find where
-- this value's field was set rather than every write to that field name in the
-- codebase. Field-only: an index/map-key in the path terminates the projection.
-- ----------------------------------------------------------------------------

-- Within a composite literal node, return the value node for the keyed element
-- whose key matches `field`, or nil if the field is not set (zero value).
local function composite_field_value(cfg, bufnr, lit, field)
  local body = lit:field(cfg.composite_body)[1]
  if not body or body:type() ~= cfg.literal_value then return nil end
  for el in body:iter_children() do
    if el:type() == cfg.keyed_element then
      local key = el:field(cfg.keyed_key)[1]
      -- key is a literal_element wrapping an identifier
      local key_text
      if key then
        local inner = key:named_child(0) or key
        key_text = node_text(bufnr, inner)
      end
      if key_text == field then
        local val = el:field(cfg.keyed_value)[1]
        if val and val:type() == cfg.literal_element then
          return val:named_child(0) or val
        end
        return val
      end
    end
  end
  return nil
end

-- Find writes of `.field` on the specific variable declared/named at the given
-- definition (scope-limited via LSP references on that variable). Returns a list
-- of value nodes assigned to `.field`, each as { cfg, bufnr, node }.
local function variable_field_writes(cfg, bufnr, var_row, var_col, field)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = var_row, character = var_col },
    context = { includeDeclaration = true },
  }
  local resps = lsp_buf_request(bufnr, 'textDocument/references', params)
  check_lsp(string.format('references (variable .%s @%d:%d)', field, var_row, var_col), resps, false)
  if not resps then return {} end

  local out, seen = {}, {}
  for _, resp in pairs(resps) do
    local client = vim.lsp.get_client_by_id(resp.client_id or 0)
    local enc = client and client.offset_encoding or 'utf-16'
    for _, loc in ipairs(resp.result or {}) do
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetRange
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true
        local b = load_buf(uri)
        local bcfg = b and cfg_for_buf(b)
        if bcfg then
          local r = range.start.line
          local c = byte_col(b, r, range.start.character, enc)
          local refnode = node_at(b, r, c)
          -- We're on the variable `v`; the write we want is `v.field = <value>`.
          -- The reference node is the operand of a selector whose field is
          -- `field`, and that selector is the LHS of an assignment.
          local sel = refnode and refnode:parent()
          if sel and sel:type() == bcfg.selector_expr then
            local fld = sel:field(bcfg.selector_field)[1]
            if fld and node_text(b, fld) == field then
              local val = classify_field_write(bcfg, fld)
              if val then
                table.insert(out, { cfg = bcfg, bufnr = b, node = val })
              end
            end
          end
        end
      end
    end
  end
  return out
end

-- Apply projection `proj` (list of field names) to `value`, producing landing
-- sites. Mirrors value_sites but carries the field path: a call descends into
-- the callee's return carrying proj; a composite literal peels one field; an
-- identifier resolves to its binding or scope-limited field writes; a selector
-- prepends its field. Unresolvable points terminate (marked) -- no codebase-wide
-- fallback. Returns a list of sites (each may carry `note` for marking).
local function project_sites(cfg, bufnr, value, proj, visited, depth, budget)
  visited = visited or {}
  depth = depth or 0
  budget = budget or { nodes = 0, max_nodes = 200, max_depth = 25 }
  local client = vim.lsp.get_clients({ bufnr = bufnr })[1]

  -- Log with the real file:line:col of `value` so it's unambiguous which code
  -- we're on (e.g. distinguishing a `c.ctx` in the user's source from our own
  -- `ctx` variable name).
  local vr0, vc0 = value:start()
  local floc = string.format('%s:%d:%d', vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.'), vr0 + 1, vc0 + 1)
  dbg(string.format('project depth=%d', depth),
    'value=' .. value:type(),
    'proj=.' .. table.concat(proj, '.'),
    'at=' .. floc,
    string.format('text=%q', node_text(bufnr, value):gsub('\n.*', '...')))

  -- Bounds: stop runaway projection (wide fan-out / deep call chains). Marked,
  -- never silent.
  budget.nodes = budget.nodes + 1
  if budget.nodes > budget.max_nodes then
    local site = landing_site(bufnr, value, client)
    site.note = 'projection budget exceeded'
    return { site }
  end
  if depth > budget.max_depth then
    local site = landing_site(bufnr, value, client)
    site.note = 'max projection depth'
    return { site }
  end

  -- Projection exhausted: fall back to ordinary value following.
  if #proj == 0 then
    return value_sites(cfg, bufnr, value, 1, {}, depth)
  end

  -- Unwrap unary (&x, *x).
  while value:type() == cfg.unary_expr do
    local operand = value:field(cfg.unary_operand)[1]
    if not operand then break end
    value = operand
  end

  local field = proj[1]
  local rest = vim.list_slice(proj, 2)

  -- Selector `a.b`: b becomes part of the projection, recurse on operand a.
  if value:type() == cfg.selector_expr then
    local operand = value:field(cfg.selector_operand)[1]
    local fld = value:field(cfg.selector_field)[1]
    if operand and fld then
      local newproj = { node_text(bufnr, fld) }
      vim.list_extend(newproj, proj)
      return project_sites(cfg, bufnr, operand, newproj, visited, depth + 1, budget)
    end
  end

  -- Composite literal: peel the matching field.
  if value:type() == cfg.composite_literal then
    local fv = composite_field_value(cfg, bufnr, value, field)
    if fv then
      return project_sites(cfg, bufnr, fv, rest, visited, depth + 1, budget)
    end
    -- Field not set in the literal: zero value, an origin. Land on the literal.
    local site = landing_site(bufnr, value, client)
    site.note = 'zero value (.' .. field .. ' not set)'
    return { site }
  end

  -- Call: descend into the callee's return carrying the projection.
  if value:type() == cfg.call_expr then
    local sites = {}
    for _, ret in ipairs(callee_returns(cfg, bufnr, value, 1)) do
      local sr, sc = ret.node:start()
      local key = string.format('%d:%d:%d:%s', ret.bufnr, sr, sc, table.concat(proj, '.'))
      if not visited[key] then
        visited[key] = true
        vim.list_extend(sites, project_sites(ret.cfg, ret.bufnr, ret.node, proj, visited, depth + 1, budget))
      end
    end
    if #sites == 0 then
      local site = landing_site(bufnr, value, client)
      site.note = 'unresolved (cannot follow .' .. table.concat(proj, '.') .. ')'
      return { site }
    end
    return sites
  end

  -- Identifier: a local or parameter. Find scope-limited `.field` writes on it,
  -- and also follow its binding (so `c := newCfg()` continues into newCfg).
  if value:type() == 'identifier' then
    local vr, vc = value:start()
    local sites = {}

    -- Direct writes of `.field` on this specific variable, in its scope.
    local fwrites = variable_field_writes(cfg, bufnr, vr, vc, field)
    dbg(string.format('  identifier .%s: %d in-scope field write(s)', field, #fwrites))
    for _, w in ipairs(fwrites) do
      vim.list_extend(sites, project_sites(w.cfg, w.bufnr, w.node, rest, visited, depth + 1, budget))
    end

    -- Resolve the variable's definition. The node here is usually a *usage*, so
    -- we ask the LSP for the declaration, then either:
    --   - follow its bound value (`c := newCfg()`) carrying the projection, or
    --   - if it is a parameter, ride the projection OUT to each call site's
    --     matching argument and keep projecting there. This is the common
    --     config-plumbing case: the struct arrives as a function parameter, and
    --     the field was set by whoever called us. Multiple callers naturally
    --     fork the tree.
    local defs = lsp_definition_at(bufnr, vr, vc)
    dbg(string.format('  identifier .%s: %d definition(s) resolved', field, #defs))
    for _, def in ipairs(defs) do
      local b = load_buf(def.uri)
      local dcfg = b and cfg_for_buf(b)
      if b and not dcfg then
        dbg('    def in buffer with no cfg (filetype not supported?)', vim.uri_to_fname(def.uri))
      end
      if dcfg then
        local enc = def.client and def.client.offset_encoding or 'utf-16'
        local dr = def.range.start.line
        local dc = byte_col(b, dr, def.range.start.character, enc)
        local dnode = node_at(b, dr, dc)

        local bound = dnode and bound_value_for(dcfg, dnode)
        local index, variadic = nil, nil
        if dnode then index, variadic = param_under_cursor(dcfg, dnode) end
        local recv = dnode and receiver_under_cursor(dcfg, dnode)
        dbg(string.format('    def @%d:%d node=%s bound=%s param_index=%s receiver=%s',
          dr, dc, dnode and dnode:type() or 'nil',
          tostring(bound ~= nil and bound.value ~= nil), tostring(index), tostring(recv ~= nil)))

        if bound and bound.value then
          local key = string.format('bind:%d:%d:%d:%s', b, dr, dc, table.concat(proj, '.'))
          if not visited[key] then
            visited[key] = true
            vim.list_extend(sites, project_sites(dcfg, b, bound.value, proj, visited, depth + 1, budget))
          end
        elseif index ~= nil then
          local fpos = enclosing_func_name_pos(dcfg, dnode)
          dbg(string.format('    param ride-out: fpos=%s', tostring(fpos ~= nil)))
          if fpos then
            local csites = incoming_call_sites(b, fpos)
            dbg(string.format('    param ride-out: %d call site(s)', #csites))
            for _, csite in ipairs(csites) do
              local arg = argument_node(csite, index, variadic)
              if arg then
                local ar, ac = arg.node:start()
                local key = string.format('arg:%d:%d:%d:%s', arg.bufnr, ar, ac, table.concat(proj, '.'))
                if not visited[key] then
                  visited[key] = true
                  vim.list_extend(sites,
                    project_sites(arg.cfg, arg.bufnr, arg.node, proj, visited, depth + 1, budget))
                end
              end
            end
          end
        elseif recv then
          -- Method receiver: ride out to each call site's selector operand
          -- (`x` in `x.Method()`), NOT argument 0, and keep projecting into x.
          local fpos = enclosing_func_name_pos(dcfg, dnode)
          dbg(string.format('    receiver ride-out: fpos=%s', tostring(fpos ~= nil)))
          if fpos then
            local csites = incoming_call_sites(b, fpos)
            dbg(string.format('    receiver ride-out: %d call site(s)', #csites))
            for _, csite in ipairs(csites) do
              local op = receiver_operand_node(csite)
              if op then
                local orow, ocol = op.node:start()
                local key = string.format('recv:%d:%d:%d:%s', op.bufnr, orow, ocol, table.concat(proj, '.'))
                if not visited[key] then
                  visited[key] = true
                  vim.list_extend(sites,
                    project_sites(op.cfg, op.bufnr, op.node, proj, visited, depth + 1, budget))
                end
              end
            end
          end
        end
      end
    end

    if #sites == 0 then
      local site = landing_site(bufnr, value, client)
      site.note = 'unresolved (.' .. table.concat(proj, '.') .. ' not set in scope)'
      return { site }
    end
    return sites
  end

  -- Anything else: cannot apply the projection here.
  local site = landing_site(bufnr, value, client)
  site.note = 'unresolved (.' .. table.concat(proj, '.') .. ')'
  return { site }
end

-- A short, single-line description of a site for a picker.
local function describe_site(site)
  local path = vim.uri_to_fname(site.uri)
  local rel = vim.fn.fnamemodify(path, ':~:.')
  local line = (site.land and site.land.row) or site.range.start.line
  local bufnr = load_buf(site.uri)
  local text = bufnr and (vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ''):gsub('^%s+', '') or ''
  return string.format('%s:%d: %s', rel, line + 1, text)
end

-- The selector field path of a node, if it is (or is within) a field read like
-- `a.b.c`: returns the innermost operand node and the list of field names in
-- order, e.g. for `cfg.Server.Port` -> (operand `cfg`, { 'Server', 'Port' }).
-- Returns nil if not a field read.
local function selector_path(cfg, bufnr, node)
  -- Climb to the outermost selector_expression covering the cursor.
  local sel = node
  if sel:type() ~= cfg.selector_expr then
    sel = find_ancestor(node, { [cfg.selector_expr] = true })
  end
  while sel and sel:parent() and sel:parent():type() == cfg.selector_expr do
    sel = sel:parent()
  end
  if not sel or sel:type() ~= cfg.selector_expr then return nil end

  -- Walk down the operand chain collecting field names.
  local fields = {}
  local cur = sel
  while cur and cur:type() == cfg.selector_expr do
    local fld = cur:field(cfg.selector_field)[1]
    if fld then table.insert(fields, 1, node_text(bufnr, fld)) end
    cur = cur:field(cfg.selector_operand)[1]
  end
  return cur, fields
end

-- ----------------------------------------------------------------------------
-- sources_at: the non-jumping core.
--
-- Given a location, return the list of "up" sources WITHOUT moving the cursor.
-- Each source is a normalized site: { uri, range, client, land, kind, chains }
-- where `land` (0-based {row,col}) is the precise spot to land on. This is the
-- shared engine for both the interactive single hop (trace_up) and the tree
-- builder. Returns { sites = <list>, empty_msg = <string for 0 results> }.
--
-- ctx (optional): { project = true } enables precise, scope-based field tracing:
-- a field read `cfg.Enabled` follows the *container* `cfg` carrying `.Enabled`
-- as a projection, resolving it at the concrete struct rather than searching the
-- whole codebase for `.Enabled` writes.
-- ----------------------------------------------------------------------------
local function sources_at(bufnr, row, col, ctx)
  ctx = ctx or {}
  -- A fresh projection budget per sources_at call: bounds one hop's worth of
  -- projection recursion (a single field read can fan out widely). The tree
  -- builder's own max_nodes/max_depth bound the overall tree on top of this.
  ctx.budget = {
    nodes = 0,
    max_nodes = ctx.project_max_nodes or Config.project_max_nodes,
    max_depth = ctx.project_max_depth or Config.project_max_depth,
  }
  local cfg = cfg_for_buf(bufnr)
  local node = cfg and node_at(bufnr, row, col)

  if cfg and node then
    -- Function/method declaration name -> its call sites. A "jump to caller",
    -- not value tracing: lands on the call, nothing to chain from.
    local fpos = func_name_decl_under_cursor(cfg, node)
    if fpos then
      local sites = incoming_call_sites(bufnr, fpos)
      for _, s in ipairs(sites) do
        s.kind = 'call-site'
        s.chains = false
      end
      return { sites = sites, empty_msg = 'trace: no call sites found (origin?)' }
    end

    -- Parameter -> the matching argument at each call site.
    local index, variadic = param_under_cursor(cfg, node)
    if index ~= nil then
      local pos = enclosing_func_name_pos(cfg, node)
      if not pos then
        return { sites = {}, empty_msg = 'trace: cannot resolve enclosing function' }
      end
      local sites = incoming_call_sites(bufnr, pos)
      for _, s in ipairs(sites) do
        s.kind = 'argument'
        s.land = argument_land(s, index, variadic)
      end
      return { sites = sites, empty_msg = 'trace: no call sites found (origin?)' }
    end

    -- Field read, in projection mode: follow the container carrying the field
    -- path, so we resolve where THIS value's field was set (scope-based) rather
    -- than every write to the field name in the codebase.
    if ctx.project then
      local field = field_under_cursor(cfg, node)
      if field then
        local operand, fields = selector_path(cfg, bufnr, node)
        if operand and fields and #fields > 0 then
          local sites = project_sites(cfg, bufnr, operand, fields, nil, 0, ctx.budget)
          for _, s in ipairs(sites) do s.kind = s.kind or 'projection' end
          return {
            sites = sites,
            empty_msg = 'trace: could not flow-resolve .' .. table.concat(fields, '.'),
          }
        end
      end
    end

    -- Struct field -> where it is written (broad / codebase-wide).
    local field = field_under_cursor(cfg, node)
    if field then
      local frow, fcol = field:start()
      local sites = field_write_sites(bufnr, { line = frow, character = fcol })
      for _, s in ipairs(sites) do s.kind = 'field-write' end
      return { sites = sites, empty_msg = 'trace: no writes to this field found' }
    end

    -- Name declared by `:=`/`var`. In projection mode, if the value is a field
    -- read, follow its container with the projection; otherwise follow normally.
    local decl = var_decl_value_under_cursor(cfg, node)
    if decl and decl.value then
      if ctx.project and decl.value:type() == cfg.selector_expr then
        local operand, fields = selector_path(cfg, bufnr, decl.value)
        if operand and fields and #fields > 0 then
          local sites = project_sites(cfg, bufnr, operand, fields, nil, 0, ctx.budget)
          for _, s in ipairs(sites) do s.kind = s.kind or 'projection' end
          return {
            sites = sites,
            empty_msg = 'trace: could not flow-resolve .' .. table.concat(fields, '.'),
          }
        end
      end
      local sites = value_sites(cfg, bufnr, decl.value, decl.result_index)
      for _, s in ipairs(sites) do s.kind = 'value' end
      return { sites = sites, empty_msg = 'trace: no value source found' }
    end
  end

  -- Fallback: go-to-definition.
  local sites = lsp_definition_at(bufnr, row, col)
  for _, s in ipairs(sites) do s.kind = 'definition' end
  return { sites = sites, empty_msg = 'trace: no definition found' }
end

-- Shared "land on a site" UX: zero sites stops with a message, one site jumps
-- silently (so chaining continues), many sites prompt (a branch point, so we
-- stop). `opts.select` overrides the picker (defaults to vim.ui.select).
local function resolve_sites(result, opts, on_done)
  local sites = result.sites
  if #sites == 0 then
    vim.notify(result.empty_msg, vim.log.levels.INFO)
    return on_done(false)
  end
  if #sites == 1 then
    goto_site(sites[1])
    return on_done(sites[1].chains ~= false)
  end
  local select = opts.select or vim.ui.select
  select(sites, { prompt = 'Trace up:', format_item = describe_site }, function(choice)
    if choice then
      goto_site(choice)
    end
    on_done(false)
  end)
end

-- One hop "up". Returns true if the cursor moved (so a caller can keep going),
-- false if we stopped (origin reached, ambiguous and prompting, or error).
-- `on_done(moved)` is called when the hop settles. opts.select overrides picker.
function M.trace_up(on_done, opts)
  on_done = on_done or function() end
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local result = sources_at(bufnr, pos[1] - 1, pos[2])
  return resolve_sites(result, opts, on_done)
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

-- ----------------------------------------------------------------------------
-- Provenance tree: all-auto, bounded expansion of sources_at.
--
-- Unlike trace_up_n (one chosen path), this explores EVERY source at each step,
-- producing a tree of provenance. Because field tracing is flow-insensitive and
-- can fan out widely, expansion is bounded (depth, total nodes) and cycles are
-- broken by a visited-set keyed on location. Truncation is recorded on the node
-- (truncated = 'depth' | 'nodes' | 'cycle') and surfaced in the render, never
-- silent. All LSP calls in sources_at are synchronous, so this runs to
-- completion in one go.
-- ----------------------------------------------------------------------------

-- The land location of a site (0-based row/col), defaulting to its range start.
local function site_land(site)
  if site.land then return site.land.row, site.land.col end
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  local b = load_buf(site.uri)
  if not b then return site.range.start.line, site.range.start.character end
  return site.range.start.line, byte_col(b, site.range.start.line, site.range.start.character, enc)
end

-- A one-line label for a tree node: "file:line: <trimmed source>".
local function node_label(uri, row)
  local b = load_buf(uri)
  local rel = vim.fn.fnamemodify(vim.uri_to_fname(uri), ':~:.')
  local text = b and (vim.api.nvim_buf_get_lines(b, row, row + 1, false)[1] or ''):gsub('^%s+', '') or ''
  return string.format('%s:%d: %s', rel, row + 1, text), b
end

-- Build a provenance tree rooted at (bufnr, row, col). opts:
--   max_depth (default 15), max_nodes (default 200),
--   project (boolean, default true) -- precise scope-based field tracing.
-- Returns the root node: { uri, row, col, kind, label, note, children = {...},
-- truncated = nil|'depth'|'nodes'|'cycle' }.
function M.build_tree(bufnr, row, col, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 15
  local max_nodes = opts.max_nodes or 200
  local ctx = { project = opts.project ~= false }
  local visited = {}
  local count = 0

  local function loc_key(uri, r, c) return string.format('%s:%d:%d', uri, r, c) end

  local function make_node(uri, b, r, c, kind, note)
    local label = node_label(uri, r)
    return { uri = uri, bufnr = b, row = r, col = c, kind = kind, note = note, label = label, children = {} }
  end

  local function expand(node, depth)
    if depth >= max_depth then
      node.truncated = 'depth'; return
    end
    local key = loc_key(node.uri, node.row, node.col)
    if visited[key] then
      node.truncated = 'cycle'; return
    end
    visited[key] = true

    local result = sources_at(node.bufnr, node.row, node.col, ctx)
    for _, site in ipairs(result.sites) do
      if count >= max_nodes then
        node.truncated = 'nodes'; break
      end
      local r, c = site_land(site)
      local b = load_buf(site.uri)
      -- A site landing on its own location is a fixpoint origin: include it as a
      -- leaf but do not expand (mirrors the linear loop's no-progress guard).
      local child = make_node(site.uri, b, r, c, site.kind, site.note)
      count = count + 1
      table.insert(node.children, child)
      -- A site carrying a `note` is a terminal (zero value / unresolved): leaf.
      if not site.note and not (b == node.bufnr and r == node.row and c == node.col) then
        expand(child, depth + 1)
      end
    end
  end

  local root_b = bufnr
  local root = make_node(vim.uri_from_bufnr(bufnr), root_b, row, col, 'root')
  expand(root, 0)
  return root
end

-- Flatten a tree (pre-order DFS) into quickfix entries with indentation +
-- box-drawing prefixes. quickfix is structurally flat, so the tree is rendered
-- as static text; each entry still jumps to real code via bufnr/lnum/col.
local function flatten_tree(node, prefix, is_last, is_root, out)
  local branch, child_prefix
  if is_root then
    branch, child_prefix = '', ''
  else
    branch = prefix .. (is_last and '└─ ' or '├─ ')
    child_prefix = prefix .. (is_last and '   ' or '│  ')
  end

  local suffix = ''
  if node.note then suffix = '  [' .. node.note .. ']' end
  if node.truncated == 'depth' then
    suffix = suffix .. '  [max depth]'
  elseif node.truncated == 'nodes' then
    suffix = suffix .. '  [max nodes]'
  elseif node.truncated == 'cycle' then
    suffix = suffix .. '  [cycle]'
  end

  table.insert(out, {
    bufnr = node.bufnr,
    lnum = node.row + 1,
    col = node.col + 1,
    text = branch .. node.label .. suffix,
  })

  for i, child in ipairs(node.children) do
    flatten_tree(child, child_prefix, i == #node.children, false, out)
  end
end

-- Build the provenance tree from the cursor and render it into a "Trace Tree"
-- quickfix list. opts is passed to build_tree (max_depth, max_nodes).
--
-- By default the build runs ASYNC inside a coroutine: the editor stays
-- responsive while gopls is queried, and the quickfix list is populated (and
-- opened) only once the whole tree is built, so the cursor is never moved
-- mid-run. Pass opts.async = false to build synchronously (blocking).
function M.trace_tree(opts)
  opts = opts or {}
  local async = opts.async ~= false
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]

  if async then
    -- Transient echo (not vim.notify) so it overwrites cleanly on completion
    -- rather than lingering in the message area behind the quickfix window.
    vim.api.nvim_echo({ { '[trace] building provenance tree...' } }, false, {})
  end

  local root
  run_traced(async, function()
    root = M.build_tree(bufnr, row, col, opts)
  end, function()
    local entries = {}
    flatten_tree(root, '', true, true, entries)
    vim.fn.setqflist({}, ' ', { title = 'Trace Tree', items = entries })
    vim.cmd('copen')
    if async then
      vim.api.nvim_echo({ { string.format('[trace] provenance tree: %d nodes', #entries) } }, false, {})
    end
  end)
end

return M
