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
    "yetone/avante.nvim",
    build = vim.fn.has("win32") ~= 0
        and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
        or "make",
    event = "VeryLazy",
    version = false, -- Never set this value to "*"! Never!
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      -- this file can contain specific instructions for your project
      instructions_file = "AGENTS.md",
      -- for example
      provider = "copilot",
      providers = {
        copilot = {
          endpoint = "https://api.githubcopilot.com",
          -- model = "claude-sonnet-4.5",
          -- model = "gpt-4o-2024-11-20",
          timeout = 30000,
          context_window = 64000,
          extra_request_body = {
            temperature = 0.75,
            max_tokens = 20480,
          },
        },
      },
      behaviour = {
        auto_suggestions = false,
        auto_approve_tool_permissions = false,
      },
      input = {
        -- provider = "snacks",
        provider_opts = {
          title = "Avante Input",
          icon = " ",
        },
      },
      windows = {
        input = {
          prefix = "> ",
          height = 20, -- Height of the input window in vertical layout
        },
        ask = {
          start_insert = false,
        },
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- "folke/snacks.nvim",
      --- The below dependencies are optional,
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",        -- for providers='copilot'
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
