return {
  {
    'neovim/nvim-lspconfig',
    config = function()
      require("plugins.configs.lspconfig").setup()
    end
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
    "chancez/codeactions-on-save.nvim",
    branch = "pr/chancez/export_handle_write_pre"
  }
}
