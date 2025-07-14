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
      },
      copilot_node_command = os.getenv('HOME') .. '/.local/bin/mise-node-lts.sh',
      server = {
        type = 'nodejs',
        custom_server_filepath = vim.fn.stdpath("data") .. "/mason/bin/copilot-language-server",
      },
      server_opts_overrides = {
        settings = {
          advanced = {
            listCount = 10,         -- #completions for panel
            inlineSuggestCount = 3, -- #completions for getCompletions
            length = 100,           -- max length of copilot suggestions
          }
        },
      }
    }
  },

  {
    "olimorris/codecompanion.nvim",
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionCmd", "CodeCompanionActions" },
    opts = {
      strategies = {
        chat = {
          adapter = "copilot",
        },
        inline = {
          adapter = "copilot",
        },
        cmd = {
          adapter = "copilot",
        },
      },
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true
          }
        }
      }
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "ravitemer/mcphub.nvim",
        opts = {
          cmd = 'mcp-hub'
        }
      },
    },
  },
}
