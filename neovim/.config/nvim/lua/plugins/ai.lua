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
    "NickvanDyke/opencode.nvim",
    dependencies = {
      -- Recommended for `ask()` and `select()`.
      -- Required for `toggle()`.
      -- { "folke/snacks.nvim", opts = { input = {}, picker = {} } },
    },
    config = function()
      vim.g.opencode_opts = {
        -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition" on `opencode_opts`.
      }

      -- Recommended/example keymaps.
      vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ", { submit = true }) end,
        { desc = "Ask about this" })
      vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end, { desc = "Select prompt" })
      vim.keymap.set({ "n", "x" }, "<leader>o+", function() require("opencode").prompt("@this") end,
        { desc = "Add this line" })
      vim.keymap.set({ "n", "x" }, "<leader>of", function() require("opencode").prompt("@buffer") end,
        { desc = "Add this buffer" })
      vim.keymap.set({ "n", "x" }, "<leader>ofs", function() require("opencode").prompt("@buffers") end,
        { desc = "Add open buffers" })
      vim.keymap.set("n", "<leader>ot", function() require("opencode").toggle() end, { desc = "Toggle embedded" })
      vim.keymap.set("n", "<leader>oc", function() require("opencode").command() end, { desc = "Select command" })
      vim.keymap.set("n", "<leader>on", function() require("opencode").command("session_new") end,
        { desc = "New session" })
      vim.keymap.set("n", "<leader>oi", function() require("opencode").command("session_interrupt") end,
        { desc = "Interrupt session" })
      vim.keymap.set("n", "<leader>oA", function() require("opencode").command("agent_cycle") end,
        { desc = "Cycle selected agent" })
      vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("messages_half_page_up") end,
        { desc = "Messages half page up" })
      vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("messages_half_page_down") end,
        { desc = "Messages half page down" })
    end,
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

