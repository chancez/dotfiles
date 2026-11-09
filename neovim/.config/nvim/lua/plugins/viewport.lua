return {
  "chancez/viewport.nvim",
  dev    = true,
  keys   = {
    { '<leader>R',    function() require('viewport').start_resize_mode() end,       desc = 'Start resize mode' },
    { '<leader>N',    function() require('viewport').start_navigate_mode() end,     desc = 'Start navigate mode' },
    { '<leader>S',    function() require('viewport').start_select_mode() end,       desc = 'Start select mode' },
    { '<leader>L',    function() require('viewport').pick_layout() end,             desc = 'Open a picker to select a layout' },
    { '<leader>sel',  function() require('viewport.actions').select_window() end,   desc = 'Select a window to focus' },
    { '<leader>swap', function() require('viewport').start_swap_mode() end,         desc = 'Select a window to swap with the current window' },
    { '<c-w>0',       function() require('viewport.actions').toggle_maximize() end, desc = 'Toggle maximize current window' },
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

    local layout_cmd = require('viewport.commands').layout
    vim.api.nvim_create_user_command('ViewportLayout', layout_cmd.run, {
      nargs = '?',
      complete = layout_cmd.complete,
      desc = 'Set the layout of the current tabpage',
    })

    -- Refresh lualine on viewport mode changes
    local grp = vim.api.nvim_create_augroup("viewport", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = grp,
      pattern = viewport.mode_change_autocmd,
      callback = function()
        require('lualine').refresh()
      end,
    })

    vim.api.nvim_create_user_command('ResizeMode', function()
      viewport.start_resize_mode()
    end, { desc = 'Start resize mode' })

    vim.api.nvim_create_user_command('NavigateMode', function()
      viewport.start_navigate_mode()
    end, { desc = 'Start navigate mode' })
  end,
}
