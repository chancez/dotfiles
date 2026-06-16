-- Editor-facing wiring for the trace engine (config.trace): config values, the
-- branch-point picker, user commands, and keymaps. Kept separate so config.trace
-- stays a pure engine. This is the single place trace is configured and wired;
-- required once from init.lua.

local trace = require('config.trace')

-- Config. One table, assigned directly. Defaults live in config.trace.M.config;
-- only override what you want here.
-- trace.config.lsp_timeout = 3000

-- Telescope-backed branch-point picker. Same contract as vim.ui.select, but with
-- a file previewer focused on each site's LANDING location (where the next hop
-- would put the cursor), so you can see each candidate source in context before
-- choosing. Falls back to vim.ui.select if telescope isn't available.
trace.config.picker = function(sites, opts, on_choice)
  local ok, pickers = pcall(require, 'telescope.pickers')
  if not ok then
    return vim.ui.select(sites, opts, on_choice)
  end
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- The picker contract requires on_choice to fire EXACTLY ONCE (with nil on
  -- cancel), else resolve_sites' on_done never runs and the trace stalls. Guard
  -- so selection and the close-without-selection path can't both fire.
  local answered = false
  local function answer(site)
    if answered then return end
    answered = true
    on_choice(site)
  end

  pickers.new(require('telescope.themes').get_ivy({}), {
    prompt_title = opts.prompt or 'Trace',
    finder = finders.new_table({
      results = sites,
      entry_maker = function(site)
        -- land is 0-based {row,col}; telescope entries are 1-based lnum/col.
        local land = site.land or { row = site.range.start.line, col = site.range.start.character }
        local filename = vim.uri_to_fname(site.uri)
        local label = opts.format_item(site)
        -- The label is `path:line: source  -> target`. Telescope writes its own
        -- `filename:lnum:` prefix to the quickfix line, so strip the label's
        -- leading `path:line:` for `text` to avoid showing the location twice.
        -- Non-greedy up to the first `:<digits>:` so paths with spaces survive.
        local qf_text = label:gsub('^.-:%d+:%s*', '')
        return {
          value = site,
          display = label,
          ordinal = label,
          filename = filename,
          lnum = land.row + 1,
          col = land.col + 1,
          -- `text` is what telescope writes to the quickfix line on <C-q>, so the
          -- rich label (source + `-> target`) survives "send to quickfix" instead
          -- of degrading to bare filename:lnum.
          text = qf_text,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    -- Built-in previewer reads entry.filename/lnum/col and highlights that line.
    previewer = conf.qflist_previewer({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        -- Answer BEFORE closing: actions.close wipes the prompt buffer, which
        -- fires the BufWipeout fallback below; the `answered` guard means
        -- whichever runs first wins, so we must record the real choice first.
        answer(entry and entry.value or nil)
        actions.close(prompt_bufnr)
      end)
      -- Any close (Esc, <C-c>, etc.) that didn't go through a selection still
      -- has to settle the trace: report no choice.
      vim.api.nvim_create_autocmd('BufWipeout', {
        buffer = prompt_bufnr,
        once = true,
        callback = function() answer(nil) end,
      })
      return true
    end,
  }):find()
end

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
