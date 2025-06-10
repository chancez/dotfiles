return {
  {
    'neovim/nvim-lspconfig',
    config = function()
      require("plugins.configs.lspconfig").setup()
    end,
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
  { 'j-hui/fidget.nvim', config = true },
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
      config = function ()
        local serverNames = require("plugins.configs.lspconfig").server_names
        require("mason-lspconfig").setup({
          ensure_installed = serverNames,
          automatic_installation = true,
          automatic_enable = true,
        })
      end
  },
}
