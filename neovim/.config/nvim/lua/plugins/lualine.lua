return {
  {
    'nvim-lualine/lualine.nvim',
    event = "VeryLazy",
    dependencies = { 'kyazdani42/nvim-web-devicons', lazy = true },
    opts = {
      options = { theme = 'onedark' },
      extensions = { 'toggleterm' },
      sections = {
        lualine_a = { 'mode', 'g:viewport_active_mode' },
        lualine_b = { 'diagnostics' },
        lualine_c = {
          {
            function()
              return require('config.util').compact_path(vim.fn.getcwd())
            end,
            icon = '📁',
          },
          {
            'filename',
            path = 1,
          }
        },
        lualine_x = {
          {
            function()
              return require("agent-session").status()
            end,
            cond = function()
              return require("agent-session.session").get_current() ~= nil
            end,
          },
          'filetype',
          'lsp_status',
        },
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
      },
      tabline = {
        lualine_a = {
          {
            'buffers',
            mode = 4,
          }
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { 'tabs' }
      }
    }
  },
}
