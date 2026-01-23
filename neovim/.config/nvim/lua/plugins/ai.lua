return {
  {
    'zbirenbaum/copilot.lua',
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      -- disable suggestions and panel since we're using cmp
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        yaml = true,
        gitcommit = true,
      },
      copilot_node_command = { "mise", "exec", "node@lts", "--", "node" },
      server = {
        type = 'nodejs',
        custom_server_filepath = vim.fn.stdpath("data") .. "/mason/bin/copilot-language-server",
      },
      server_opts_overrides = {
        settings = {
          advanced = {
            listCount = 10,         -- #completions for panel
            inlineSuggestCount = 3, -- #completions for getCompletions
            length = 300,           -- max length of copilot suggestions
          }
        },
      }
    }
  },
  {
    "carlos-algms/agentic.nvim",
    opts = {
      -- provider = "codex-acp",
      provider = "claude-acp",
      acp_providers = {
        ["claude-acp"] = {
          default_mode = "acceptEdits",
          env = {
            AWS_PROFILE = "bedrock",
            CLAUDE_CODE_USE_BEDROCK = "true",
            -- ANTHROPIC_MODEL = "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
            ANTHROPIC_MODEL = "us.anthropic.claude-opus-4-5-20251101-v1:0",
          },
        },
      },

      windows = {
        width = "33%",
      },
    },
    config = function(_, opts)
      require("agentic").setup(opts)
      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'AgenticInput',
        callback = function(ev)
          -- Defer the setting to ensure it runs after the plugin's setup
          vim.schedule(function()
            vim.b[ev.buf].completion = true
          end)
        end,
      })
    end,
    keys = {
      {
        "<leader>ac",
        function() require("agentic").toggle() end,
        mode = { "n", "v", "i" },
        desc = "Toggle Agentic Chat"
      },
      {
        "<leader>af",
        function() require("agentic").add_selection_or_file_to_context({ focus_prompt = false }) end,
        mode = { "n", "v" },
        desc = "Add file or selection to Agentic to Context"
      },
      {
        "<leader>aF",
        function()
          local SessionRegistry = require("agentic.session_registry")
          SessionRegistry.get_session_for_tab_page(nil, function(session)
            -- Get the currently visible buffers based on the windows in the current tab
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              -- Check the buffer is valid and loaded and not an agentic buffer
              local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
              if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not ft:match("^Agentic") then
                session:add_file_to_session(buf)
              end
            end
          end)
        end,
        mode = { "n", "v" },
        desc = "Add visible buffers to Agentic Context"
      },
      {
        "<leader>aq",
        function()
          local SessionRegistry = require("agentic.session_registry")
          SessionRegistry.get_session_for_tab_page(nil, function(session)
            -- Get the quickfix list items
            local qflist = vim.fn.getqflist()
            -- Track unique buffer numbers to avoid duplicates
            local seen_bufs = {}
            for _, item in ipairs(qflist) do
              if item.bufnr and item.bufnr > 0 and not seen_bufs[item.bufnr] then
                seen_bufs[item.bufnr] = true
                -- Check the buffer is valid and loaded
                local ft = vim.api.nvim_get_option_value("filetype", { buf = item.bufnr })
                if vim.api.nvim_buf_is_valid(item.bufnr) then
                  session:add_file_to_session(item.bufnr)
                end
              end
            end
          end)
        end,
        mode = { "n", "v" },
        desc = "Add files from quickfix list to Agentic Context"
      },
      {
        "<leader>an",
        function() require("agentic").new_session() end,
        mode = { "n", "v", "i" },
        desc = "New Agentic Session"
      },
      {
        "<leader>as",
        function() require("agentic").stop_generation() end,
        mode = { "n", "v", "i" },
        desc = "Stop current generation"
      },
    },
  }
}

