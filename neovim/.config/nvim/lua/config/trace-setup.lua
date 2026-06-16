-- Editor-facing wiring for the trace engine (config.trace): config values, the
-- branch-point picker, user commands, and keymaps. Kept separate so config.trace
-- stays a pure engine. This is the single place trace is configured and wired;
-- required once from init.lua.

local trace = require('config.trace')

-- Config. One table, assigned directly. Defaults live in config.trace.M.config;
-- only override what you want here. (picker = a custom branch-point picker with
-- the vim.ui.select contract; left nil = use vim.ui.select.)
-- trace.config.lsp_timeout = 3000
-- trace.config.picker = function(sites, opts, on_choice) ... end

-- Commands ------------------------------------------------------------------

-- Trace a value one hop "up" toward its origin. With a count, repeat that many
-- times, stopping early at any branch point (multiple call sites) or origin.
vim.api.nvim_create_user_command('TraceUp', function(cmd)
  trace.trace_up_n(cmd.count > 0 and cmd.count or 1)
end, { count = true, desc = "Trace a value one hop up toward its origin (accepts a count)" })

-- Trace a value all the way to its origin, recording the path into a "Trace"
-- quickfix list. Auto-hops until an origin or a branch point; a count caps hops.
vim.api.nvim_create_user_command('TraceOrigin', function(cmd)
  trace.trace_up_n(cmd.count > 0 and cmd.count or 1000, { quickfix = true })
end, { count = true, desc = "Trace a value to its origin, recording the path into a quickfix list" })

-- Build the full provenance tree (all sources, all branches, bounded) from the
-- cursor and render it into a "Trace Tree" quickfix list. A count caps depth.
vim.api.nvim_create_user_command('TraceTree', function(cmd)
  local opts = {}
  if cmd.count > 0 then opts.max_depth = cmd.count end
  trace.trace_tree(opts)
end, { count = true, desc = "Build the full provenance tree into a quickfix list" })

-- Toggle trace debug logging (LSP timeouts/errors and projection hops, shown in
-- :messages). With a bang, force on; otherwise toggle.
vim.api.nvim_create_user_command('TraceDebug', function(cmd)
  trace.config.debug = cmd.bang or not trace.config.debug
  print('Trace debug ' .. (trace.config.debug and 'enabled' or 'disabled'))
end, { bang = true, desc = "Toggle trace debug logging (:messages)" })

-- Keymaps -------------------------------------------------------------------

-- `gu`: one hop up (with count, repeat, stopping at branches/origin).
vim.keymap.set('n', 'gu', function()
  trace.trace_up_n(vim.v.count1)
end, { desc = "Trace value up toward origin" })

-- `gU`: auto-hop to the origin, recording the path into a "Trace" quickfix list.
-- A count caps the hops.
vim.keymap.set('n', 'gU', function()
  local count = vim.v.count > 0 and vim.v.count or 1000
  trace.trace_up_n(count, { quickfix = true })
end, { desc = "Trace value to origin (quickfix trail)" })

-- `gz`: full provenance tree into a "Trace Tree" quickfix list. A count caps
-- depth. (gt/gT are taken by tabs; gz keeps the trace family on the g-prefix.)
vim.keymap.set('n', 'gz', function()
  local opts = {}
  if vim.v.count > 0 then opts.max_depth = vim.v.count end
  trace.trace_tree(opts)
end, { desc = "Trace value provenance tree (quickfix)" })
