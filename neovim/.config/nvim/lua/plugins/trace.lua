-- trace.nvim: trace a value back toward its origin (gu/gU/gz/gp). A local plugin
-- vendored in the dotfiles repo (neovim/trace.nvim), referenced by `dir` so lazy
-- loads it in place with no version tracking. The plugin is a pure engine; all
-- wiring (settings, picker, commands, keymaps) lives here in the spec.
return {
  {
    dir = vim.fn.expand("~/.dotfiles/neovim/trace.nvim"),
    -- Load on first use of a trace mapping or command (engine stays cold at startup).
    keys = {
      { "gu", function() require("trace").trace_up_n(vim.v.count1) end, desc = "Trace value up toward origin" },
      {
        "gU",
        function()
          local count = vim.v.count > 0 and vim.v.count or 1000
          require("trace").trace_up_n(count, { quickfix = true })
        end,
        desc = "Trace value to origin (quickfix trail)",
      },
      {
        "gz",
        function()
          local opts = {}
          if vim.v.count > 0 then opts.max_depth = vim.v.count end
          require("trace").trace_tree(opts)
        end,
        desc = "Trace value provenance tree (quickfix)",
      },
      { "gp", function() require("trace").peek() end, desc = "Peek at value trace sources (no jump)" },
    },
    cmd = { "TraceUp", "TraceOrigin", "TraceTree", "TracePeek", "TraceDebug" },
    -- Settings (merged into trace.config by setup). Functions live here too, in
    -- the spirit of keeping all config in opts.
    opts = {
      peek_context = 3,
      -- Telescope-backed branch-point picker. Same contract as vim.ui.select, but
      -- with a file previewer focused on each site's LANDING location (where the
      -- next hop lands), so you can see each candidate in context before choosing.
      -- Falls back to vim.ui.select if telescope isn't available.
      picker = function(sites, opts, on_choice)
        local ok, pickers = pcall(require, "telescope.pickers")
        if not ok then
          return vim.ui.select(sites, opts, on_choice)
        end
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        -- The picker contract requires on_choice to fire EXACTLY ONCE (with nil on
        -- cancel), else resolve_sites' on_done never runs and the trace stalls.
        -- Guard so selection and the close-without-selection path can't both fire.
        local answered = false
        local function answer(site)
          if answered then return end
          answered = true
          on_choice(site)
        end

        -- The chosen site, captured on selection and consumed once the picker has
        -- fully closed (see select_default / BufWipeout below). nil = cancelled.
        local choice = nil

        pickers.new(require("telescope.themes").get_ivy({}), {
          prompt_title = opts.prompt or "Trace",
          finder = finders.new_table({
            results = sites,
            entry_maker = function(site)
              -- land is 0-based {row,col}; telescope entries are 1-based lnum/col.
              local land = site.land or { row = site.range.start.line, col = site.range.start.character }
              local filename = vim.uri_to_fname(site.uri)
              local label = opts.format_item(site)
              -- The label is `path:line: source  -> target`. Telescope writes its
              -- own `filename:lnum:` prefix to the quickfix line, so strip the
              -- label's leading `path:line:` for `text` to avoid showing the
              -- location twice. Non-greedy up to the first `:<digits>:` so paths
              -- with spaces survive.
              local qf_text = label:gsub("^.-:%d+:%s*", "")
              return {
                value = site,
                display = label,
                ordinal = label,
                filename = filename,
                lnum = land.row + 1,
                col = land.col + 1,
                -- `text` is what telescope writes to the quickfix line on <C-q>,
                -- so the rich label (source + `-> target`) survives "send to
                -- quickfix" instead of degrading to bare filename:lnum.
                text = qf_text,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          -- Built-in previewer reads entry.filename/lnum/col and highlights the line.
          previewer = conf.qflist_previewer({}),
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              -- Record the choice, then close. We must NOT answer (and thus jump)
              -- here: on_choice -> goto_site -> vim.lsp.util.show_document runs
              -- while the telescope prompt window is still current, so
              -- show_document swaps that window's buffer, which tears down the
              -- picker and closes the window out from under show_document's own
              -- nvim_set_current_win (E5108: invalid window id). Defer the answer
              -- to BufWipeout, which fires after telescope has restored the
              -- original window, so the jump targets a live window.
              choice = action_state.get_selected_entry()
              choice = choice and choice.value or nil
              actions.close(prompt_bufnr)
            end)
            -- The single settle point for every close path (selection, Esc,
            -- <C-c>): answer with the recorded choice, or nil if cancelled
            -- without a selection. Runs after the prompt window is gone.
            vim.api.nvim_create_autocmd("BufWipeout", {
              buffer = prompt_bufnr,
              once = true,
              callback = function()
                vim.schedule(function() answer(choice) end)
              end,
            })
            return true
          end,
        }):find()
      end,
    },
    config = function(_, opts)
      local trace = require("trace")
      trace.setup(opts)

      -- Commands. Mappings live in `keys` above; commands are defined here (the
      -- `cmd` list only tells lazy which command names should load the plugin).

      -- Trace a value one hop "up" toward its origin. With a count, repeat that
      -- many times, stopping early at any branch point or origin.
      vim.api.nvim_create_user_command("TraceUp", function(cmd)
        trace.trace_up_n(cmd.count > 0 and cmd.count or 1)
      end, { count = true, desc = "Trace a value one hop up toward its origin (accepts a count)" })

      -- Trace a value all the way to its origin, recording the path into a "Trace"
      -- quickfix list. Auto-hops until an origin or branch point; a count caps hops.
      vim.api.nvim_create_user_command("TraceOrigin", function(cmd)
        trace.trace_up_n(cmd.count > 0 and cmd.count or 1000, { quickfix = true })
      end, { count = true, desc = "Trace a value to its origin, recording the path into a quickfix list" })

      -- Build the full provenance tree from the cursor into a "Trace Tree"
      -- quickfix list. A count caps depth.
      vim.api.nvim_create_user_command("TraceTree", function(cmd)
        local o = {}
        if cmd.count > 0 then o.max_depth = cmd.count end
        trace.trace_tree(o)
      end, { count = true, desc = "Build the full provenance tree into a quickfix list" })

      -- Peek at where the value under the cursor would trace to, in a float,
      -- without moving the cursor.
      vim.api.nvim_create_user_command("TracePeek", function()
        trace.peek()
      end, { desc = "Peek at a value's trace sources in a float (no jump)" })

      -- Toggle trace debug logging (LSP timeouts/errors and projection hops, shown
      -- in :messages). With a bang, force on; otherwise toggle.
      vim.api.nvim_create_user_command("TraceDebug", function(cmd)
        trace.config.debug = cmd.bang or not trace.config.debug
        print("Trace debug " .. (trace.config.debug and "enabled" or "disabled"))
      end, { bang = true, desc = "Toggle trace debug logging (:messages)" })
    end,
  },
}
