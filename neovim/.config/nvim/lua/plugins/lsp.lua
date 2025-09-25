return {
  {
    'neovim/nvim-lspconfig',
  },
  {
    'ray-x/lsp_signature.nvim',
    opts = {
      zindex = 50,
      bind = true, -- This is mandatory, otherwise border config won't get registered.
      handler_opts = {
        border = "rounded"
      },
      toggle_key = "<M-x>",
      floating_window_off_x = 60,
    }
  },
  { 'onsails/lspkind-nvim' },
  {
    'j-hui/fidget.nvim',
    opts = {
      notification = {
        window = {
          max_width = 50
        },
      },
    }
  },
  {
    'williamboman/mason.nvim',
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗"
        }
      }
    }
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      local myLspConfigs = require("plugins.configs.lspconfig")
      local serverNames = myLspConfigs.auto_install_servers
      require("mason-lspconfig").setup({
        ensure_installed = serverNames,
        automatic_installation = true,
        automatic_enable = false,
      })
      myLspConfigs.setup()
    end
  },
}
