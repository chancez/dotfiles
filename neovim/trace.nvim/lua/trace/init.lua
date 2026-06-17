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

-- ----------------------------------------------------------------------------
-- Types (LuaLS annotations). The recurring data shapes used throughout.
-- ----------------------------------------------------------------------------

---A 0-based cursor/landing position within a buffer.
---@class trace.Land
---@field row integer 0-based line
---@field col integer 0-based byte column

---Per-language treesitter node/field names. Scalar fields are node-type or
---field-name strings; set fields are `table<string, true>` of node types.
---@class trace.LangSpec
---@field func_decl table<string, true> function/method declaration node types
---@field method_decl string method_declaration node type
---@field receiver_field string field name of a method's receiver parameter_list
---@field param_list string parameter_list node type
---@field param_decl table<string, true> parameter declaration node types
---@field variadic_decl table<string, true> variadic parameter declaration node types
---@field call_expr string call_expression node type
---@field call_func_field string field name of a call's function
---@field selector_expr string selector_expression node type
---@field selector_field string field name of a selector's field
---@field selector_operand string field name of a selector's operand
---@field arg_list string argument_list node type
---@field short_var_decl string short_var_declaration node type
---@field var_spec string var_spec node type
---@field var_spec_name string field name of a var_spec's names
---@field var_spec_value string field name of a var_spec's value
---@field return_stmt string return_statement node type
---@field func_literal string func_literal node type
---@field func_body string field name of a function body
---@field unary_expr string unary_expression node type
---@field unary_operand string field name of a unary expression's operand
---@field composite_literal string composite_literal node type
---@field composite_type string field name of a composite literal's type
---@field composite_body string field name of a composite literal's body
---@field literal_value string literal_value node type
---@field literal_element string literal_element node type
---@field qualified_type string qualified_type node type
---@field qualified_name string field name of a qualified type's name
---@field import_spec string import_spec node type (a package import)
---@field field_ref table<string, true> node types that name a field
---@field field_ref_exclude_parent table<string, true> parents that disqualify a field ref
---@field composite_key_ref table<string, true> node types valid as a struct-literal key
---@field assignment string assignment_statement node type
---@field assign_left string field name of an assignment's left side
---@field assign_right string field name of an assignment's right side
---@field expr_list string expression_list node type
---@field inc_dec table<string, true> increment/decrement statement node types
---@field keyed_element string keyed_element node type
---@field keyed_key string field name of a keyed element's key
---@field keyed_value string field name of a keyed element's value

---A branch-point picker, same contract as `vim.ui.select`.
---@alias trace.Picker fun(sites: trace.Site[], opts: { prompt: string, format_item: fun(site: trace.Site): string }, on_choice: fun(site: trace.Site?))

---Module configuration (M.config).
---@class trace.Config
---@field debug boolean log diagnostics to :messages
---@field lsp_timeout integer per-LSP-request timeout, ms
---@field lsp_ready_timeout integer ms to wait for an idle LSP client before tracing
---@field project_hops boolean projection-aware interactive hops (gu/gU); stateless, per-hop
---@field project_max_nodes integer projection fan-out cap
---@field project_max_depth integer projection recursion-depth cap
---@field peek_max_sites integer max sources rendered in the peek float
---@field peek_context integer lines of context shown before/after each peek site
---@field picker trace.Picker? branch-point picker (else vim.ui.select)

---A normalized "up" source: a place to jump to, plus how to render/continue it.
---@class trace.Site
---@field uri string document URI of the source
---@field range lsp.Range the LSP range (its start is the fallback land position)
---@field client vim.lsp.Client? the client that produced it (for offset encoding)
---@field land trace.Land? precise 0-based spot to land on (else range start)
---@field kind string? classification (call-site|argument|field-write|value|projection|definition|root)
---@field chains boolean? false = do not auto-continue from here (jump-to-caller)
---@field note string? terminal marker (zero value / unresolved / budget), shown in renders

---Result of sources_at: the sources plus a message for the zero-result case.
---@class trace.SourcesResult
---@field sites trace.Site[]
---@field empty_msg string
---@field projection string? the field path being projected (e.g. ".Enabled"), set only in projection mode

---A treesitter value node together with the buffer and lang spec it lives in.
---Used to carry write/return/argument results across buffers. `row`/`col` are
---only set where ordering matters (variable_writes).
---@class trace.NodeRef
---@field cfg trace.LangSpec
---@field bufnr integer
---@field node TSNode
---@field row integer?
---@field col integer?
---@field result_index integer? tuple position to follow (callee returns)

---The value feeding a declared name: an expression node and the tuple position
---to follow within it (for `v, err := f()` style multi-returns).
---@class trace.BoundValue
---@field value TSNode
---@field result_index integer

---A return expression and the tuple position to follow within it.
---@class trace.ReturnExpr
---@field node TSNode
---@field result_index integer

---Projection recursion bounds, threaded through project_sites.
---@class trace.Budget
---@field nodes integer running count of visited nodes
---@field max_nodes integer fan-out cap
---@field max_depth integer recursion-depth cap

---Context threaded through sources_at / build_tree.
---@class trace.Ctx
---@field project boolean? enable precise scope-based field tracing
---@field project_max_nodes integer? override M.config.project_max_nodes
---@field project_max_depth integer? override M.config.project_max_depth
---@field budget trace.Budget? per-call projection budget (set internally)

---A node in the provenance tree built by build_tree.
---@class trace.TreeNode
---@field uri string
---@field bufnr integer?
---@field row integer 0-based
---@field col integer 0-based
---@field kind string?
---@field note string?
---@field label string rendered "file:line: source" label
---@field children trace.TreeNode[]
---@field truncated ('depth'|'nodes'|'cycle')? why this node was not expanded

-- Configuration. A single plain table is the ONE place config lives -- read at
-- use time as `M.config.<key>`, written by assigning into it (do that from your
-- own setup file, keeping this module a pure engine). No vim.g, no setter, no
-- setup() -- one read path, one write path.
--
-- `picker` is a custom branch-point picker (multiple sources). Same contract as
-- vim.ui.select:
--   picker(sites, { prompt = string, format_item = fn(site)->string }, on_choice)
-- where `sites` are the raw site tables ({ uri, range, land = {row,col}, kind })
-- so a custom picker (e.g. telescope) can build a preview from each site, and
-- on_choice(site|nil) is called with the chosen site or nil if cancelled.
---@type trace.Config
M.config = {
  debug = false,             -- log diagnostics (see dbg/check_lsp) to :messages
  lsp_timeout = 2000,        -- per-LSP-request timeout, ms
  lsp_ready_timeout = 10000, -- ms to wait for an idle LSP client before tracing
  project_hops = true,       -- gu/gU use projection (stateless, per-hop)
  project_max_nodes = 200,   -- projection fan-out cap
  project_max_depth = 25,    -- projection recursion-depth cap
  peek_max_sites = 10,       -- max sources rendered in the peek float
  peek_context = 0,          -- lines of context before/after each peek site
  picker = nil,              -- branch-point picker (else vim.ui.select)
}

-- Merge `opts` into M.config. The classic lazy.nvim entry point: a spec's `opts`
-- table is passed here so settings live in `opts` like any other plugin. Plain
-- shallow merge (config is a flat table); omitted keys keep their defaults.
---@param opts trace.Config? overrides to merge into M.config
function M.setup(opts)
  if opts then
    M.config = vim.tbl_extend('force', M.config, opts)
  end
end

-- Per-language treesitter node names.
---@type table<string, trace.LangSpec>
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
    import_spec = 'import_spec', -- a package import; operand resolving here = a package, not a value

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

-- Extmark namespace for highlighting the landing line in the peek float.
local peek_ns = vim.api.nvim_create_namespace('trace_peek')

-- Extmark namespace for marking candidate options in the SOURCE buffers during a
-- peek (only sites in currently-visible windows; cleared when the peek dismisses).
local option_ns = vim.api.nvim_create_namespace('trace_peek_options')

---@param bufnr integer
---@return trace.LangSpec? spec the lang spec for the buffer's filetype, or nil
local function cfg_for_buf(bufnr)
  return langs[vim.bo[bufnr].filetype]
end


-- Whether any client on `bufnr` has in-flight work-done progress (e.g. gopls
-- indexing the workspace). A client can be attached but still indexing, which
-- yields incomplete trace results.
--
-- We read `client.progress.pending` -- a token->title map of UNFINISHED progress
-- sequences maintained by neovim's core $/progress handler. This is current
-- STATE (not an event stream), so it is correct no matter when we start looking
-- (no missed-begin bootstrap hole) and, unlike iterating client.progress, does
-- not consume the ring buffer the statusline uses.
---@param bufnr integer
---@return boolean
local function lsp_progress_active(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local pending = client.progress and client.progress.pending
    if pending and next(pending) ~= nil then
      return true
    end
  end
  return false
end

-- Debug logging, toggled with M.config.debug. Visible via :messages.
---@param ... any parts (strings used as-is, others vim.inspect'd)
local function dbg(...)
  if not M.config.debug then return end
  local parts = {}
  for _, v in ipairs({ ... }) do
    parts[#parts + 1] = type(v) == 'string' and v or vim.inspect(v)
  end
  vim.notify('[trace] ' .. table.concat(parts, ' '), vim.log.levels.INFO)
end

-- Inspect a synchronous LSP result, logging whether it timed out, errored, or
-- came back empty. `where` labels the call site. Returns the result unchanged.
---@generic T
---@param where string label for the call site
---@param res_or_resps T the LSP result (single request_sync result, or buf_request_sync map)
---@param single boolean true for a single client:request_sync result shape
---@return T res_or_resps unchanged
local function check_lsp(where, res_or_resps, single)
  if not M.config.debug then return res_or_resps end
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
---@param co thread the traced coroutine
---@param ... any values passed to coroutine.resume
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
---@param bufnr integer
---@param method string LSP method
---@param params table request params
---@return table<integer, {error: lsp.ResponseError?, result: any}>? results map, or nil
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
  vim.defer_fn(function() finish(nil) end, M.config.lsp_timeout)

  return coroutine.yield()
end

-- buf_request, dual-mode: async (awaited) inside a coroutine, sync otherwise.
---@param bufnr integer
---@param method string LSP method
---@param params table request params
---@return table<integer, {error: lsp.ResponseError?, result: any}>? results map, or nil
local function lsp_buf_request(bufnr, method, params)
  ---@diagnostic disable-next-line: deprecated
  if coroutine.isyieldable() then
    return await_buf_request(bufnr, method, params)
  end
  return vim.lsp.buf_request_sync(bufnr, method, params, M.config.lsp_timeout)
end

-- A client on `bufnr` is "ready" when one is attached AND none is mid-progress
-- (e.g. gopls finished indexing). Attached-but-indexing is the common cause of
-- incomplete results right after startup, so waiting for attach alone is not
-- enough -- we must also wait for progress to drain.
---@param bufnr integer
---@return boolean
local function lsp_ready(bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr }) > 0 and not lsp_progress_active(bufnr)
end

-- Wait (non-blocking) until the LSP is ready on `bufnr`, then call `cb(ready)`.
-- If already ready, calls cb(true) SYNCHRONOUSLY (so callers stay snappy when
-- gopls is up); otherwise polls on the main loop and calls cb(true) once ready
-- or cb(false) after lsp_ready_timeout. Usable outside a coroutine.
---@param bufnr integer
---@param cb fun(ready: boolean)
local function wait_lsp_ready(bufnr, cb)
  if lsp_ready(bufnr) then
    return cb(true)
  end
  local deadline = M.config.lsp_ready_timeout
  local interval = 100
  local waited = 0
  local timer = assert(vim.uv.new_timer())
  timer:start(interval, interval, vim.schedule_wrap(function()
    waited = waited + interval
    local ready = lsp_ready(bufnr)
    if ready or waited >= deadline then
      timer:stop()
      timer:close()
      cb(ready)
    end
  end))
end

-- Await until the LSP is ready (see lsp_ready) on `bufnr`. Polls on the main
-- loop without blocking; returns true once ready, or false after
-- lsp_ready_timeout. Only valid inside a coroutine. (The not-ready path always
-- resumes on a later tick, never synchronously, so we never resume a running
-- coroutine.)
---@param bufnr integer
---@return boolean ready
local function await_lsp_ready(bufnr)
  if lsp_ready(bufnr) then
    return true
  end
  local co = assert(coroutine.running(), 'await_lsp_ready must run in a coroutine')
  -- Defer the resume: wait_lsp_ready may invoke its cb synchronously (if the
  -- buffer became ready between our check and its recheck), which would resume
  -- this coroutine before it has yielded. vim.schedule guarantees a later tick.
  wait_lsp_ready(bufnr, function(ready)
    vim.schedule(function() resume_co(co, ready) end)
  end)
  return coroutine.yield()
end

-- Run `fn` either inside a fresh coroutine (when `async` is true) or directly.
-- The coroutine drives itself: the first resume runs until the first await's
-- yield, and each LSP callback resumes it, so `fn` runs to completion across
-- many event-loop ticks without blocking. `done()` is called (scheduled) when
-- fn returns, in both async and sync modes.
---@param async boolean run fn inside a coroutine (true) or directly (false)
---@param fn fun() the traced body
---@param done fun()? called (scheduled) when fn returns
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
---@param node TSNode?
---@param types table<string, true> set of node types to match
---@return TSNode? ancestor the matching ancestor (or self), or nil
local function find_ancestor(node, types)
  while node do
    if types[node:type()] then
      return node
    end
    node = node:parent()
  end
end

---@param a TSNode?
---@param b TSNode?
---@return boolean
local function nodes_equal(a, b)
  if not (a and b) then return false end
  local ar, ac = a:start()
  local br, bc = b:start()
  return ar == br and ac == bc and a:type() == b:type()
end

-- Named children of a node, as a list.
---@param node TSNode
---@return TSNode[]
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
---@param node TSNode
---@param target TSNode
---@return integer? index 1-based, or nil if not a named child
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
---@param parent TSNode
---@param node TSNode
---@return integer? index 1-based, or nil
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
---@param bufnr integer
---@param node TSNode
---@return string
local function node_text(bufnr, node)
  return vim.treesitter.get_node_text(node, bufnr)
end

-- Convert an LSP (utf-16 by default) character offset to a byte column.
---@param bufnr integer
---@param row integer 0-based line
---@param character integer LSP character offset
---@param encoding string? offset encoding (default 'utf-16')
---@return integer col 0-based byte column
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
-- Attach any already-running LSP client whose config supports buffer `b`'s
-- filetype. A background-loaded buffer (vim.fn.bufload) has lines but no LSP
-- attached -- the cross-file twin of the node_at treesitter bug -- so references
-- and definition on it return "no client" and projection dead-ends. We reuse the
-- live client (cheap: sends didOpen, no server spawn) so those files resolve
-- without ever being opened. Returns true if a client is now attached.
---@param b integer bufnr
---@return boolean attached
local function ensure_lsp_attached(b)
  if #vim.lsp.get_clients({ bufnr = b }) > 0 then
    return true
  end
  -- Background bufload may not have run filetype detection; do it so we can match
  -- clients by filetype.
  if vim.bo[b].filetype == '' then
    pcall(function() vim.api.nvim_buf_call(b, function() vim.cmd('filetype detect') end) end)
  end
  local ft = vim.bo[b].filetype
  local attached = false
  for _, client in ipairs(vim.lsp.get_clients()) do
    ---@diagnostic disable-next-line: undefined-field
    local fts = client.config and client.config.filetypes
    if (not fts or vim.tbl_contains(fts, ft)) and vim.lsp.buf_attach_client(b, client.id) then
      attached = true
    end
  end
  return attached
end

---@param uri string a document URI or a filesystem path
---@return integer? bufnr the loaded buffer, or nil if it couldn't be loaded
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
  ensure_lsp_attached(b)
  return b
end

-- Treesitter node at (row, col) (0-based) in `bufnr`. A buffer loaded in the
-- background (vim.fn.bufload) has its lines but no parsed treesitter tree, so a
-- plain vim.treesitter.get_node returns nil for it. We force a parse first, so
-- cross-file lookups (call sites, definitions in other files) work without the
-- buffer ever being displayed.
---@param bufnr integer
---@param row integer 0-based line
---@param col integer 0-based byte column
---@return TSNode? node the node at the position, or nil
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
---@param cfg trace.LangSpec
---@param plist TSNode a parameter_list node
---@return boolean
local function is_receiver_list(cfg, plist)
  local parent = plist:parent()
  if not parent or parent:type() ~= cfg.method_decl then return false end
  local recv = parent:field(cfg.receiver_field)[1]
  return recv and nodes_equal(recv, plist) or false
end

-- If `node` is a method receiver, return its declaration node, else nil.
---@param cfg trace.LangSpec
---@param node TSNode?
---@return TSNode? receiver_decl
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return integer? index 0-based flat parameter index, or nil
---@return boolean? variadic whether the parameter is variadic
local function param_under_cursor(cfg, node)
  if not node then return nil end

  local pdecl = find_ancestor(node, cfg.param_decl)
  if not pdecl then return nil end
  local plist = pdecl:parent()
  if not plist or plist:type() ~= cfg.param_list then return nil end
  if is_receiver_list(cfg, plist) then return nil end

  -- The identifier the cursor is actually on (for multi-name params).
  ---@type TSNode?
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return lsp.Position? pos 0-based {line, character} of the decl name, or nil
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return lsp.Position? pos 0-based {line, character} of the enclosing func name, or nil
local function enclosing_func_name_pos(cfg, node)
  node = find_ancestor(node, cfg.func_decl)
  if not node then return nil end
  local name = node:field('name')[1]
  if not name then return nil end -- anonymous func literal: no call hierarchy
  local row, col = name:start()
  return { line = row, character = col }
end

-- Collect call sites of the function whose name is at `pos` via call hierarchy.
---@param bufnr integer
---@param pos lsp.Position 0-based position of the function name
---@return trace.Site[] sites
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
      local client = vim.lsp.get_client_by_id(client_id)
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

-- Refine an assigned-value node to the node we should actually LAND on, so the
-- next hop continues from the meaningful sub-node: unwrap leading unary (`&x`,
-- `*x`) and, for a field read `a.b.c`, land on the trailing field rather than the
-- operand `a` (the same rule value_sites applies; field_write_sites and
-- argument_land build their landings independently and must apply it too).
---@param cfg trace.LangSpec
---@param value TSNode the assigned-value node
---@return TSNode landing the node to actually land on
local function refine_landing_node(cfg, value)
  -- A struct-literal keyed value comes wrapped in a literal_element; unwrap to
  -- the real expression (e.g. the selector inside `BatchSize: ing.cfg.BatchSize`).
  if value:type() == cfg.literal_element then
    value = value:named_child(0) or value
  end
  while value:type() == cfg.unary_expr do
    local operand = value:field(cfg.unary_operand)[1]
    if not operand then break end
    value = operand
  end
  if value:type() == cfg.selector_expr then
    return value:field(cfg.selector_field)[1] or value
  end
  return value
end

-- Compute the 0-based { row, col } landing for argument `index` of the call at
-- `site` (an LSP location). Returns nil to mean "land on the call itself"
-- (function-name case, or no matching argument). Loads the buffer but does not
-- move the cursor, so it can be used while merely building data. The argument
-- expression is refined (refine_landing_node) so a selector arg `cfg.Field` or
-- `&x` lands on the field/operand, not the front of the expression.
---@param site trace.Site the call site
---@param index integer? 0-based argument index (nil = land on the call itself)
---@param variadic boolean? whether the parameter is variadic
---@return trace.Land? land 0-based landing, or nil to land on the call
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
  if not call then
    dbg(string.format('      argument_land @%d:%d node=%s -> no call_expression ancestor',
      row, col, node and node:type() or 'nil'))
    return nil
  end
  local args = call:field('arguments')[1]
  if not args or args:type() ~= cfg.arg_list then
    dbg('      argument_land: call has no argument_list')
    return nil
  end

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
    dbg(string.format('      argument_land: want index %d but call has %d args (%q)',
      index, #named, node_text(b, call):gsub('\n.*', '...')))
    return nil
  end

  -- Land on the meaningful sub-node: for a selector arg `cfg.Field` the start of
  -- the expression is the operand `cfg`, so refine to the trailing field (and
  -- unwrap `&x`/`*x`), matching where value_sites/field_write_sites land.
  target = refine_landing_node(cfg, target)
  dbg(string.format('      argument_land: index %d of %d args -> %q in (%q)',
    index, #named, node_text(b, target):gsub('\n.*', '...'),
    node_text(b, call):gsub('\n.*', '...')))
  local r, c = target:start()
  return { row = r, col = c }
end

-- Like argument_land, but returns the argument's treesitter node along with its
-- buffer and cfg: { cfg, bufnr, node }. Used by projection to keep tracing into
-- the argument expression. Returns nil if no matching argument.
---@param site trace.Site the call site
---@param index integer? 0-based argument index
---@param variadic boolean? whether the parameter is variadic
---@return trace.NodeRef? ref the argument node, or nil
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
---@param site trace.Site the call site
---@return trace.NodeRef? ref the receiver operand node, or nil
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
---@param site trace.Site
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return TSNode? field the field-name node, or nil
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
---@param cfg trace.LangSpec
---@param ref TSNode the reference node (a field or identifier)
---@return TSNode|false|nil value source value node, false for a sourceless write, nil for a read
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
-- treesitter classification.
---@param bufnr integer
---@param pos lsp.Position 0-based position of the field name
---@return trace.Site[] sites
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
  for client_id, resp in pairs(resps) do
    local client = vim.lsp.get_client_by_id(client_id)
    local enc = client and client.offset_encoding or 'utf-16'
    for _, loc in ipairs(resp.result or {}) do
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetRange
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true

        local b = load_buf(uri)
        local cfg = b and cfg_for_buf(b)
        if b and cfg then
          local row = range.start.line
          local col = byte_col(b, row, range.start.character, enc)
          local ref = node_at(b, row, col)
          if ref then
            local value = classify_field_write(cfg, ref)
            if value ~= nil then
              local land = { row = row, col = col }
              if value then
                local vr, vc = refine_landing_node(cfg, value):start()
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
---@param bufnr integer
---@param row integer 0-based line
---@param col integer 0-based byte column
---@return trace.Site[] sites definition sites (deduped)
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
---@param bufnr integer
---@param node TSNode
---@param encoding string? offset encoding (default 'utf-16')
---@return lsp.Range
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
---@param bufnr integer
---@param node TSNode the node to land on
---@param client vim.lsp.Client? for offset encoding
---@return trace.Site
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
---@param n_targets integer number of assignment targets
---@param value_list TSNode the value expression_list
---@param idx integer 1-based target index
---@return trace.BoundValue
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return trace.BoundValue? bound
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
---@param cfg trace.LangSpec
---@param node TSNode?
---@return trace.BoundValue? bound
local function var_decl_value_under_cursor(cfg, node)
  return bound_value_for(cfg, node)
end

-- Return expressions for tuple position `result_index` across all return
-- statements directly in `func_node`'s body (nested function literals pruned,
-- since their returns belong to a different scope). Each result is
-- { node, result_index }: the expression and, if it is itself a call, the tuple
-- position to follow within it (preserved across `return f()` passthroughs).
---@param cfg trace.LangSpec
---@param func_node TSNode a function/method declaration or func_literal
---@param result_index integer 1-based tuple position
---@return trace.ReturnExpr[] returns
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
---@param cfg trace.LangSpec
---@param call TSNode a call_expression
---@return TSNode? name the callee name node, or nil
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
---@param cfg trace.LangSpec
---@param bufnr integer
---@param call TSNode a call_expression
---@param result_index integer 1-based tuple position
---@return trace.NodeRef[] returns return expressions with their buffer/cfg
local function callee_returns(cfg, bufnr, call, result_index)
  local name_node = call_name_node(cfg, call)
  if not name_node then return {} end
  local fr, fc = name_node:start()
  local defs = lsp_definition_at(bufnr, fr, fc)

  local out = {}
  for _, def in ipairs(defs) do
    local b = load_buf(def.uri)
    local dcfg = b and cfg_for_buf(b)
    if b and dcfg then
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
---@param cfg trace.LangSpec
---@param bufnr integer
---@param value TSNode the value node to follow
---@param result_index integer 1-based tuple position
---@param visited table<string, true>? cycle-guard (keyed by location)
---@param depth integer? recursion depth
---@return trace.Site[] sites
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
  -- writes" -- itself a useful signal. (Same rule field_write_sites applies via
  -- refine_landing_node.)
  if value:type() == cfg.selector_expr then
    return { landing_site(bufnr, refine_landing_node(cfg, value), client) }
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
---@param cfg trace.LangSpec
---@param bufnr integer
---@param lit TSNode a composite_literal
---@param field string the field name to match
---@return TSNode? value the keyed element's value node, or nil
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
-- of value nodes assigned to `.field`, each as { cfg, bufnr, node }. The lang
-- spec is derived per result buffer, so the start buffer's spec is not needed.
---@param bufnr integer
---@param var_row integer 0-based line of the variable
---@param var_col integer 0-based byte column of the variable
---@param field string the field name to match
---@return trace.NodeRef[] writes
local function variable_field_writes(bufnr, var_row, var_col, field)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = var_row, character = var_col },
    context = { includeDeclaration = true },
  }
  local resps = lsp_buf_request(bufnr, 'textDocument/references', params)
  check_lsp(string.format('references (variable .%s @%d:%d)', field, var_row, var_col), resps, false)
  if not resps then return {} end

  local out, seen = {}, {}
  for client_id, resp in pairs(resps) do
    local client = vim.lsp.get_client_by_id(client_id)
    local enc = client and client.offset_encoding or 'utf-16'
    for _, loc in ipairs(resp.result or {}) do
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetRange
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true
        local b = load_buf(uri)
        local bcfg = b and cfg_for_buf(b)
        if b and bcfg then
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

-- Find all the value-sources of a plain local variable at (var_row, var_col):
-- the declaration's RHS (`x := <value>` / `var x = <value>`) AND every later
-- reassignment (`x = <value>`, `x += <value>`). The variable analog of
-- field-write tracing -- scope-limited via LSP references on the variable, so it
-- only sees writes in the enclosing function. Each result is a value node as
-- { cfg, bufnr, node }; a write with no source (e.g. `x++`) is skipped.
-- Returns the list, which may have several entries (branches), latest-first.
-- The lang spec is derived per result buffer, so the start spec is not needed.
---@param bufnr integer
---@param var_row integer 0-based line of the variable
---@param var_col integer 0-based byte column of the variable
---@return trace.NodeRef[] writes value sources, ordered latest-write-first
local function variable_writes(bufnr, var_row, var_col)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = var_row, character = var_col },
    context = { includeDeclaration = true },
  }
  local resps = lsp_buf_request(bufnr, 'textDocument/references', params)
  check_lsp(string.format('references (variable @%d:%d)', var_row, var_col), resps, false)
  if not resps then return {} end

  local out, seen = {}, {}
  for client_id, resp in pairs(resps) do
    local client = vim.lsp.get_client_by_id(client_id)
    local enc = client and client.offset_encoding or 'utf-16'
    for _, loc in ipairs(resp.result or {}) do
      local uri = loc.uri or loc.targetUri
      local range = loc.range or loc.targetRange
      local key = string.format('%s:%d:%d', uri, range.start.line, range.start.character)
      if not seen[key] then
        seen[key] = true
        local b = load_buf(uri)
        local bcfg = b and cfg_for_buf(b)
        if b and bcfg then
          local r = range.start.line
          local c = byte_col(b, r, range.start.character, enc)
          local refnode = node_at(b, r, c)
          if refnode then
            -- A declaration name (`x := v` / `var x = v`): take its bound value.
            local bound = bound_value_for(bcfg, refnode)
            if bound and bound.value then
              table.insert(out, { cfg = bcfg, bufnr = b, node = bound.value, row = r, col = c })
            else
              -- A reassignment (`x = v` / `x += v`): classify_field_write's
              -- assignment branch maps a plain-identifier LHS to its value slot
              -- too. nil = a read; false = a write with no source (skip both).
              local val = classify_field_write(bcfg, refnode)
              if val then
                table.insert(out, { cfg = bcfg, bufnr = b, node = val, row = r, col = c })
              end
            end
          end
        end
      end
    end
  end

  -- Order latest-write-first: reading backward from the use, the nearest
  -- preceding write (a reassignment) should come before the declaration. Sort by
  -- source position descending (same buffer here, since references on a local are
  -- function-scoped; uri is included to keep it total).
  table.sort(out, function(a, b)
    if a.bufnr ~= b.bufnr then return a.bufnr > b.bufnr end
    if a.row ~= b.row then return a.row > b.row end
    return a.col > b.col
  end)
  return out
end

-- Apply projection `proj` (list of field names) to `value`, producing landing
-- sites. Mirrors value_sites but carries the field path: a call descends into
-- the callee's return carrying proj; a composite literal peels one field; an
-- identifier resolves to its binding or scope-limited field writes; a selector
-- prepends its field. Unresolvable points terminate (marked) -- no codebase-wide
-- fallback. Returns a list of sites (each may carry `note` for marking).
---@param cfg trace.LangSpec
---@param bufnr integer
---@param value TSNode the container value to follow
---@param proj string[] the pending field path (e.g. { 'Server', 'Port' })
---@param visited table<string, true>? cycle-guard (keyed by location + proj)
---@param depth integer? recursion depth
---@param budget trace.Budget? projection bounds
---@return trace.Site[] sites
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

    -- The field node (`proj[1]` as it appears in source), used for the package
    -- case below: for `time.Second`, value is the operand `time`, and its parent
    -- selector's field child is `Second`.
    local sel = value:parent()
    local field_node = sel and sel:type() == cfg.selector_expr
        and sel:field(cfg.selector_field)[1] or nil

    -- Direct writes of `.field` on this specific variable, in its scope.
    local fwrites = variable_field_writes(bufnr, vr, vc, field)
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
      if b and dcfg then
        local enc = def.client and def.client.offset_encoding or 'utf-16'
        local dr = def.range.start.line
        local dc = byte_col(b, dr, def.range.start.character, enc)
        local dnode = node_at(b, dr, dc)

        local bound = dnode and bound_value_for(dcfg, dnode)
        local index, variadic = nil, nil
        if dnode then index, variadic = param_under_cursor(dcfg, dnode) end
        local recv = dnode and receiver_under_cursor(dcfg, dnode)
        -- A package qualifier (`time` in `time.Second`): the operand's definition
        -- lands in an import_spec, not a value. So instead of following the
        -- package name (which would dead-end, or via gtd fan out across the whole
        -- package), resolve the FIELD's definition directly -- gtd on `Second`
        -- lands on its declaration in the package source.
        local is_pkg = dnode and find_ancestor(dnode, { [dcfg.import_spec] = true }) ~= nil
        dbg(string.format('    def @%d:%d node=%s bound=%s param_index=%s receiver=%s pkg=%s',
          dr, dc, dnode and dnode:type() or 'nil',
          tostring(bound ~= nil and bound.value ~= nil), tostring(index),
          tostring(recv ~= nil), tostring(is_pkg)))

        if is_pkg and field_node then
          -- Resolve `.field`'s own definition (the package-level declaration).
          local fr, fc = field_node:start()
          for _, fdef in ipairs(lsp_definition_at(bufnr, fr, fc)) do
            local fb = load_buf(fdef.uri)
            local fcfg = fb and cfg_for_buf(fb)
            if fb and fcfg then
              local fenc = fdef.client and fdef.client.offset_encoding or 'utf-16'
              local fdr = fdef.range.start.line
              local fdc = byte_col(fb, fdr, fdef.range.start.character, fenc)
              local fdnode = node_at(fb, fdr, fdc)
              -- The field's declaration is the origin for this package symbol;
              -- land there and continue following any remaining projection from
              -- its bound value (e.g. `const Second = ...`).
              local fbound = fdnode and bound_value_for(fcfg, fdnode)
              if fbound and fbound.value then
                local key = string.format('pkgfield:%d:%d:%d:%s', fb, fdr, fdc, table.concat(rest, '.'))
                if not visited[key] then
                  visited[key] = true
                  vim.list_extend(sites, project_sites(fcfg, fb, fbound.value, rest, visited, depth + 1, budget))
                end
              elseif fdnode then
                vim.list_extend(sites, { landing_site(fb, fdnode, fdef.client) })
              end
            end
          end
        elseif bound and bound.value then
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
---@param site trace.Site
---@return string
local function describe_site(site)
  local path = vim.uri_to_fname(site.uri)
  local rel = vim.fn.fnamemodify(path, ':~:.')
  local line = (site.land and site.land.row) or site.range.start.line
  local bufnr = load_buf(site.uri)
  local text = bufnr and (vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ''):gsub('^%s+', '') or ''

  -- The source line alone doesn't show WHERE on it the hop lands (e.g. for
  -- `shardCount = 1` you can't tell it lands on `1` vs `shardCount`). Append the
  -- exact landing target: the treesitter node at the land position.
  local target
  if bufnr and site.land then
    local n = node_at(bufnr, site.land.row, site.land.col)
    if n then
      target = node_text(bufnr, n):gsub('\n.*', '...')
      if target == text then target = nil end -- whole-line node adds nothing
    end
  end

  if target then
    return string.format('%s:%d: %s  -> %s', rel, line + 1, text, target)
  end
  return string.format('%s:%d: %s', rel, line + 1, text)
end

-- Pull the source line for `site` plus `context` lines on each side from its
-- buffer, dedented by the common leading whitespace so the block reads cleanly
-- while keeping relative indentation. Returns the lines, the language for the
-- fence, and the 0-based index of the target line within the returned snippet
-- (so the caller can highlight it). With context 0 this is just the
-- (left-trimmed) single line at index 0.
---@param site trace.Site
---@param context integer lines of context before/after
---@return string[] lines the (dedented) code lines
---@return string ft the filetype for the code fence
---@return integer target 0-based index of the landing line within `lines`
local function peek_snippet(site, context)
  local bufnr = load_buf(site.uri)
  if not bufnr then return { '' }, '', 0 end
  local ft = vim.bo[bufnr].filetype or ''
  local lnum = (site.land and site.land.row) or site.range.start.line -- 0-based
  local last = vim.api.nvim_buf_line_count(bufnr) - 1
  local first = math.max(0, lnum - context)
  local stop = math.min(last, lnum + context)
  local raw = vim.api.nvim_buf_get_lines(bufnr, first, stop + 1, false)

  -- Common leading whitespace across non-blank lines, so we dedent the block
  -- without flattening relative indentation.
  local common
  for _, l in ipairs(raw) do
    if l:match('%S') then
      local indent = l:match('^%s*')
      if not common or #indent < #common then common = indent end
    end
  end
  common = common or ''
  local dedented = {}
  for _, l in ipairs(raw) do
    table.insert(dedented, (l:gsub('^' .. common, '', 1)))
  end

  -- open_floating_preview's markdown normalization collapses SUCCESSIVE blank
  -- lines (it does not respect code fences), which would shift the landing line.
  -- Pre-collapse them ourselves so normalization is a no-op and the target index
  -- stays exact; track the landing line's new position as we drop lines.
  local target = lnum - first
  local out = {}
  local prev_blank = false
  for idx, l in ipairs(dedented) do
    local blank = l:match('^%s*$') ~= nil
    if blank and prev_blank then
      if idx - 1 < target then target = target - 1 end -- a line before target dropped
    else
      table.insert(out, l)
    end
    prev_blank = blank
  end
  return out, ft, target
end

-- Render a sources result as markdown lines for the peek float. Each source is a
-- bold relative `path:line` header + dim `(kind)` (plus its terminal note, if
-- any), then the source line (with peek_context lines around it) in a fenced
-- code block so open_floating_preview gives it real syntax highlighting. Many
-- sources stack with `---` rules, capped at peek_max_sites with a "+N more"
-- line. Zero sources renders the empty message.
--
-- Also returns the 0-based float-buffer line numbers of each landing line, so
-- the caller can highlight them. open_floating_preview's markdown normalization
-- keeps every line in place (it only strips CRs, collapses SUCCESSIVE blank
-- lines, and expands `---` 1:1), so our emitted indices match the float buffer
-- as long as we never emit two blank lines in a row -- which we do not.
---@param result trace.SourcesResult
---@return string[] lines markdown lines for open_floating_preview
---@return integer[] targets 0-based float-buffer lines of each landing line
local function peek_lines(result)
  local sites = result.sites
  if #sites == 0 then
    return { result.empty_msg }, {}
  end

  local lines = {}
  local targets = {}
  local shown = math.min(#sites, M.config.peek_max_sites)
  for i = 1, shown do
    local site = sites[i]
    local path = vim.uri_to_fname(site.uri)
    local rel = vim.fn.fnamemodify(path, ':~:.')
    local lnum = ((site.land and site.land.row) or site.range.start.line) + 1
    local snippet, ft, target = peek_snippet(site, M.config.peek_context)

    -- Location reads first (bold), the hop kind trails as a dim parenthetical so
    -- it is visually distinct from the path. In projection mode the projected
    -- field path rides inside that parenthetical (e.g. `(projection: .Enabled)`),
    -- so the indicator costs no extra line and the highlight mapping is untouched.
    -- Terminal note (if any) appended.
    local kind = site.kind or 'source'
    if result.projection and kind == 'projection' then
      kind = kind .. ': ' .. result.projection
    end
    local header = string.format('**%s:%d** (%s)', rel, lnum, kind)
    if site.note then
      header = header .. ' [' .. site.note .. ']'
    end
    if i > 1 then
      table.insert(lines, '---')
    end
    table.insert(lines, header)
    table.insert(lines, '```' .. ft)
    -- The landing line sits at `target` within the snippet, which begins on the
    -- next emitted line. Record its 0-based float-buffer position.
    table.insert(targets, #lines + target)
    vim.list_extend(lines, snippet)
    table.insert(lines, '```')
  end
  if #sites > shown then
    table.insert(lines, '---')
    table.insert(lines, string.format('... (+%d more)', #sites - shown))
  end
  return lines, targets
end

-- The selector field path of a node, if it is (or is within) a field read like
-- `a.b.c`: returns the innermost operand node and the list of field names in
-- order, e.g. for `cfg.Server.Port` -> (operand `cfg`, { 'Server', 'Port' }).
-- Returns nil if not a field read.
---@param cfg trace.LangSpec
---@param bufnr integer
---@param node TSNode
---@return TSNode? operand the innermost operand (or nil if not a field read)
---@return string[]? fields the field names in order
local function selector_path(cfg, bufnr, node)
  -- Climb to the outermost selector_expression covering the cursor. `node` is
  -- non-nil; `sel` becomes optional only because the loop below may walk off the
  -- top via :parent().
  ---@type TSNode?
  local sel = node
  if node:type() ~= cfg.selector_expr then
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
---@param bufnr integer
---@param row integer 0-based line
---@param col integer 0-based byte column
---@param ctx trace.Ctx? tracing context (projection toggle, bounds)
---@return trace.SourcesResult
local function sources_at(bufnr, row, col, ctx)
  ctx = ctx or {}
  -- A fresh projection budget per sources_at call: bounds one hop's worth of
  -- projection recursion (a single field read can fan out widely). The tree
  -- builder's own max_nodes/max_depth bound the overall tree on top of this.
  ctx.budget = {
    nodes = 0,
    max_nodes = ctx.project_max_nodes or M.config.project_max_nodes,
    max_depth = ctx.project_max_depth or M.config.project_max_depth,
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
      dbg(string.format('param branch: flat index=%d variadic=%s', index, tostring(variadic)))
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
          local path = '.' .. table.concat(fields, '.')
          return {
            sites = sites,
            empty_msg = 'trace: could not flow-resolve ' .. path,
            projection = path,
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

    -- Name declared by `:=`/`var`, cursor on the declaration name itself. In
    -- projection mode, if the value is a field read, follow its container with
    -- the projection. (Handled here, before the general variable case, because a
    -- projected selector RHS needs the container-following treatment.)
    local decl = var_decl_value_under_cursor(cfg, node)
    if decl and decl.value and ctx.project and decl.value:type() == cfg.selector_expr then
      local operand, fields = selector_path(cfg, bufnr, decl.value)
      if operand and fields and #fields > 0 then
        local sites = project_sites(cfg, bufnr, operand, fields, nil, 0, ctx.budget)
        for _, s in ipairs(sites) do s.kind = s.kind or 'projection' end
        local path = '.' .. table.concat(fields, '.')
        return {
          sites = sites,
          empty_msg = 'trace: could not flow-resolve ' .. path,
          projection = path,
        }
      end
    end

    -- A plain local variable, whether the cursor is on the declaration name or a
    -- later use. Trace ALL its value-sources: the declaration's RHS plus every
    -- reassignment (the variable analog of field-write tracing). Multiple writes
    -- become branches. We detect "is a local variable" by asking for its writes;
    -- if it has any, this is the case (a package/func/type name yields none and
    -- falls through to go-to-definition).
    if node:type() == 'identifier' then
      local writes = variable_writes(bufnr, row, col)
      if #writes > 0 then
        local sites = {}
        for _, w in ipairs(writes) do
          for _, s in ipairs(value_sites(w.cfg, w.bufnr, w.node, 1)) do
            s.kind = s.kind or 'value'
            table.insert(sites, s)
          end
        end
        return { sites = sites, empty_msg = 'trace: no value source found' }
      end
    end
  end

  -- Fallback: go-to-definition.
  local sites = lsp_definition_at(bufnr, row, col)
  for _, s in ipairs(sites) do s.kind = 'definition' end
  return { sites = sites, empty_msg = 'trace: no definition found' }
end

-- The set of buffers currently displayed in a window. Option marks are only
-- drawn in these (off-screen / other-file sites can't be seen anyway; they live
-- in the float / picker). Returns a set keyed by bufnr.
---@return table<integer, true>
local function visible_buffers()
  local vis = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vis[vim.api.nvim_win_get_buf(win)] = true
  end
  return vis
end

-- Clear any option marks left in any buffer (idempotent; safe to call anytime).
local function clear_option_marks()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      vim.api.nvim_buf_clear_namespace(b, option_ns, 0, -1)
    end
  end
end

-- When a hop/peek surfaces MORE THAN ONE candidate, mark the ones that live in a
-- currently-visible buffer, so the spread of in-file options is visible in place
-- before you choose. Off-screen sites are skipped (only surveyable in the float /
-- picker). Uses Search (not Visual) so it reads as "candidate", not an accidental
-- selection, in your real buffer. Returns true if any mark was drawn.
---@param sites trace.Site[]
---@return boolean marked
local function mark_visible_options(sites)
  if #sites < 2 then return false end
  local vis = visible_buffers()
  local marked = false
  for _, site in ipairs(sites) do
    local b = vim.uri_to_bufnr(site.uri)
    if vis[b] and vim.api.nvim_buf_is_loaded(b) then
      local row = site.land and site.land.row or site.range.start.line
      vim.api.nvim_buf_set_extmark(b, option_ns, row, 0, {
        line_hl_group = 'Search',
      })
      marked = true
    end
  end
  return marked
end

-- Shared "land on a site" UX: zero sites stops with a message, one site jumps
-- silently (so chaining continues), many sites prompt (a branch point, so we
-- stop). `opts.select` overrides the picker (defaults to vim.ui.select). At a
-- branch we mark the in-file options before prompting, so the spread is visible
-- while choosing; the marks are cleared once a choice settles.
---@param result trace.SourcesResult
---@param opts { select: trace.Picker? }
---@param on_done fun(moved: boolean)
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
  -- Branch point: mark the in-file candidates so you can see them in place while
  -- the picker is up. Cleared when the choice settles below (jump or cancel).
  clear_option_marks()
  mark_visible_options(sites)
  local select = opts.select or M.config.picker or vim.ui.select
  select(sites, { prompt = 'Trace up', format_item = describe_site }, function(choice)
    clear_option_marks()
    if choice then
      goto_site(choice)
    end
    on_done(false)
  end)
end

-- One hop "up". Returns true if the cursor moved (so a caller can keep going),
-- false if we stopped (origin reached, ambiguous and prompting, or error).
-- `on_done(moved)` is called when the hop settles. opts.select overrides picker.
-- opts.project enables projection for this hop (stateless: each hop re-derives
-- the field path from what's under the cursor, nothing is carried between hops);
-- defaults to M.config.project_hops.
---@param on_done fun(moved: boolean)?
---@param opts { select: trace.Picker?, project: boolean? }?
function M.trace_up(on_done, opts)
  on_done = on_done or function() end
  opts = opts or {}
  local project = opts.project
  if project == nil then project = M.config.project_hops end
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local result = sources_at(bufnr, pos[1] - 1, pos[2], { project = project })
  return resolve_sites(result, opts, on_done)
end

-- Peek at where the value under the cursor would trace to, WITHOUT moving. Shows
-- the sources in an LSP-hover-style float, one block per source. Projection is ON
-- by default (precise, scope-based field tracing; pass project=false for the
-- projection-free `gu`-style view). Gates on LSP-ready exactly like trace_up_n so
-- the peek is trustworthy right after startup (sync-fast when already ready).
---@param opts { project: boolean? }?
function M.peek(opts)
  opts = opts or {}
  local project = opts.project ~= false -- default on; explicit false disables
  local bufnr = vim.api.nvim_get_current_buf()
  local function show()
    -- Clear marks from any prior peek before drawing this one's.
    clear_option_marks()
    local pos = vim.api.nvim_win_get_cursor(0)
    local result = sources_at(bufnr, pos[1] - 1, pos[2], { project = project })
    local lines, targets = peek_lines(result)
    local fbuf = vim.lsp.util.open_floating_preview(lines, 'markdown', {
      border = 'rounded',
      focus_id = 'trace-peek',
    })
    -- Highlight each landing line so it stands out from the surrounding context
    -- (only meaningful when peek_context > 0). line_hl_group spans the full line.
    for _, l in ipairs(targets) do
      vim.api.nvim_buf_set_extmark(fbuf, peek_ns, l, 0, {
        line_hl_group = 'Visual',
      })
    end
    -- Mark the in-file candidate options (when there's a branch) so the spread is
    -- visible in place. Clear them on the SAME events the float closes on, so the
    -- marks and float dismiss together (focusing into the float to scroll does
    -- not fire CursorMoved, so the marks survive that, matching the float).
    if mark_visible_options(result.sites) then
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertCharPre' }, {
        once = true,
        callback = clear_option_marks,
      })
    end
  end
  if lsp_ready(bufnr) then
    return show()
  end
  vim.api.nvim_echo({ { '[trace] waiting for LSP...' } }, false, {})
  wait_lsp_ready(bufnr, function(ready)
    if not ready then
      vim.api.nvim_echo({ { '[trace] no LSP client ready after '
      .. M.config.lsp_ready_timeout .. 'ms; aborting', 'ErrorMsg' } }, true, {})
      return
    end
    vim.api.nvim_echo({ { '' } }, false, {}) -- clear the "waiting" message
    show()
  end)
end

-- Build a quickfix entry describing the current cursor position.
---@return vim.quickfix.entry
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
---@return { buf: integer, row: integer, col: integer }
local function cursor_location()
  local pos = vim.api.nvim_win_get_cursor(0)
  return { buf = vim.api.nvim_get_current_buf(), row = pos[1], col = pos[2] }
end

---@param a { buf: integer, row: integer, col: integer }?
---@param b { buf: integer, row: integer, col: integer }?
---@return boolean
local function same_location(a, b)
  return a ~= nil and b ~= nil and a.buf == b.buf and a.row == b.row and a.col == b.col
end

-- Repeat trace_up up to `count` times, stopping early at any branch point or
-- origin. opts:
--   quickfix (boolean)  when true, record the start position and every hop into
--                       a new quickfix list titled "Trace", opening it at the end.
--   project (boolean)   projection-aware hops (defaults to M.config.project_hops).
---@param count integer? number of hops (default 1)
---@param opts { quickfix: boolean?, select: trace.Picker?, project: boolean? }?
function M.trace_up_n(count, opts)
  opts = opts or {}
  count = math.max(count or 1, 1)
  local record = opts.quickfix == true

  -- Record the launch site in the jumplist ONCE (not per hop), so after tracing
  -- down a branch you can `<C-o>` back to where you started and `gu` again to
  -- pick a sibling branch. `m'` sets the ' mark, which seeds the jumplist.
  vim.cmd("normal! m'")

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
    end, { select = opts.select, project = opts.project })
  end

  -- Wait for the LSP to be ready before the first hop (just like trace_tree):
  -- running right after startup against a still-indexing gopls otherwise fails.
  -- When already ready (the common case) this runs synchronously, so `gu` stays
  -- instant; only a cold/indexing server defers.
  local bufnr = vim.api.nvim_get_current_buf()
  if lsp_ready(bufnr) then
    return step(count)
  end
  vim.api.nvim_echo({ { '[trace] waiting for LSP...' } }, false, {})
  wait_lsp_ready(bufnr, function(ready)
    if not ready then
      vim.api.nvim_echo({ { '[trace] no LSP client ready after '
      .. M.config.lsp_ready_timeout .. 'ms; aborting', 'ErrorMsg' } }, true, {})
      return
    end
    vim.api.nvim_echo({ { '' } }, false, {}) -- clear the "waiting" message
    step(count)
  end)
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
---@param site trace.Site
---@return integer row 0-based
---@return integer col 0-based
local function site_land(site)
  if site.land then return site.land.row, site.land.col end
  local enc = site.client and site.client.offset_encoding or 'utf-16'
  local b = load_buf(site.uri)
  if not b then return site.range.start.line, site.range.start.character end
  return site.range.start.line, byte_col(b, site.range.start.line, site.range.start.character, enc)
end

-- A one-line label for a tree node: "file:line: <trimmed source>".
---@param uri string
---@param row integer 0-based line
---@return string label
---@return integer? bufnr the loaded buffer (or nil)
local function node_label(uri, row)
  local b = load_buf(uri)
  local rel = vim.fn.fnamemodify(vim.uri_to_fname(uri), ':~:.')
  local text = b and (vim.api.nvim_buf_get_lines(b, row, row + 1, false)[1] or ''):gsub('^%s+', '') or ''
  return string.format('%s:%d: %s', rel, row + 1, text), b
end

-- Build a provenance tree rooted at (bufnr, row, col). opts:
--   max_depth (default 15), max_nodes (default 200),
--   project (boolean, default true) -- precise scope-based field tracing.
-- Returns the root node.
---@param bufnr integer
---@param row integer 0-based line
---@param col integer 0-based byte column
---@param opts { max_depth: integer?, max_nodes: integer?, project: boolean? }?
---@return trace.TreeNode root
function M.build_tree(bufnr, row, col, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 15
  local max_nodes = opts.max_nodes or 200
  local ctx = { project = opts.project ~= false }
  local visited = {}
  local count = 0

  local function loc_key(uri, r, c) return string.format('%s:%d:%d', uri, r, c) end

  ---@param uri string
  ---@param b integer?
  ---@param r integer
  ---@param c integer
  ---@param kind string?
  ---@param note string?
  ---@return trace.TreeNode
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
---@param node trace.TreeNode
---@param prefix string accumulated indentation prefix
---@param is_last boolean whether this node is the last child
---@param is_root boolean whether this is the tree root
---@param out vim.quickfix.entry[] accumulator
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
---@param opts { max_depth: integer?, max_nodes: integer?, project: boolean?, async: boolean? }?
function M.trace_tree(opts)
  opts = opts or {}
  local async = opts.async ~= false
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]

  -- Transient echo (not vim.notify) so it overwrites cleanly on completion
  -- rather than lingering in the message area behind the quickfix window.
  local function echo(msg)
    vim.api.nvim_echo({ { msg } }, false, {})
  end

  if async then
    -- Reflect whether we're about to wait on the LSP, so the message isn't a
    -- misleading "building..." while we're actually blocked on gopls indexing.
    if lsp_ready(bufnr) then
      echo('[trace] building provenance tree...')
    else
      echo('[trace] waiting for LSP...')
    end
  end

  local root
  local failed = false
  local indexing = false
  run_traced(async, function()
    -- Wait for gopls (or whichever client) before tracing: starting while it is
    -- still loading yields incomplete results. In sync mode we cannot await, so
    -- just check presence. On timeout, abort with an error rather than building
    -- a misleading partial tree.
    if async then
      if not await_lsp_ready(bufnr) then
        failed = true
        return
      end
      -- Wait done; now actually building (overwrites the "waiting" message).
      echo('[trace] building provenance tree...')
    elseif #vim.lsp.get_clients({ bufnr = bufnr }) == 0 then
      failed = true
      return
    end
    -- Even after awaiting readiness, indexing can resume mid-build (or in sync
    -- mode we never waited); if so, results may be incomplete, so note and warn.
    indexing = lsp_progress_active(bufnr)
    root = M.build_tree(bufnr, row, col, opts)
    indexing = indexing or lsp_progress_active(bufnr)
  end, function()
    if failed then
      vim.api.nvim_echo(
        { { '[trace] no LSP client ready after '
        .. M.config.lsp_ready_timeout .. 'ms; aborting', 'ErrorMsg' } }, true, {})
      return
    end
    local nodes = {}
    flatten_tree(root, '', true, true, nodes)
    local entries = {}
    -- If the LSP was indexing during the build, results may be incomplete: warn
    -- as the first quickfix entry (invalid, so it doesn't hijack navigation).
    if indexing then
      table.insert(entries, {
        valid = 0,
        text = '[trace] WARNING: LSP was still indexing -- results may be incomplete',
      })
    end
    vim.list_extend(entries, nodes)
    vim.fn.setqflist({}, ' ', { title = 'Trace Tree', items = entries })
    vim.cmd('copen')
    if async then
      local extra = indexing and ' (LSP indexing -- may be incomplete)' or ''
      vim.api.nvim_echo({ {
        string.format('[trace] provenance tree: %d nodes%s', #nodes, extra),
      } }, false, {})
    end
  end)
end

return M
