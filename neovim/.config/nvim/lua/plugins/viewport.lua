return {
  "chancez/viewport.nvim",
  dev    = true,
  lazy   = false,
  keys   = {
    { '<leader>R', function() require('viewport.resize').start() end,                 desc = 'Start resize mode' },
    { '<leader>N', function() require('viewport.navigate').start() end,               desc = 'Start navigate mode' },
    { '<leader>S', function() require('viewport.navigate').actions.select_mode() end, desc = 'Start select mode' },
  },
  cmd    = {
    "ResizeMode",
    "NavigateMode",
  },
  config = function()
    local resize = require('viewport.resize')
    resize.setup({
      resize_amount = 5,
      mappings = {
        preset = 'relative',
      },
    })

    local navigate = require('viewport.navigate')
    navigate.setup()

    vim.api.nvim_create_user_command('ResizeMode', function()
      resize.start()
    end, { desc = 'Start resize mode' })

    vim.api.nvim_create_user_command('NavigateMode', function()
      navigate.start()
    end, { desc = 'Start navigate mode' })
  end,
}
