return {
  "chancez/viewport.nvim",
  dev    = true,
  lazy   = false,
  keys   = {
    { '<leader>R',    function() require('viewport').start_resize_mode() end,     desc = 'Start resize mode' },
    { '<leader>N',    function() require('viewport').start_navigate_mode() end,   desc = 'Start navigate mode' },
    { '<leader>S',    function() require('viewport').start_select_mode() end,     desc = 'Start select mode' },
    { '<leader>sel',  function() require('viewport.actions').select_window() end, desc = 'Select a window to focus' },
    { '<leader>swap', function() require('viewport.actions').select_swap() end,   desc = 'Select a window to swap with the current window' },
  },
  cmd    = {
    "ResizeMode",
    "NavigateMode",
  },
  config = function()
    local viewport = require('viewport')
    viewport.setup({
      resize_mode = {
        resize_amount = 5,
        mappings = {
          preset = 'relative',
        },
      }
    })

    vim.api.nvim_create_user_command('ResizeMode', function()
      viewport.start_resize_mode()
    end, { desc = 'Start resize mode' })

    vim.api.nvim_create_user_command('NavigateMode', function()
      viewport.start_navigate_mode()
    end, { desc = 'Start navigate mode' })
  end,
}
