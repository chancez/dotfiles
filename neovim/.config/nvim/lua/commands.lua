local util = require 'util'

-- Open help in a new tab
vim.api.nvim_create_user_command('HelpTab', ':help <args> | wincmd T', { nargs = 1, complete = 'help' })
vim.api.nvim_create_user_command('HelpVert', ':vert botright help <args>', { nargs = 1, complete = 'help' })

-- Quit all buffers and delete the current session
vim.api.nvim_create_user_command('Qas', function()
  vim.cmd(':silent AutoSession delete')
  vim.cmd(':silent AutoSession disable')
  vim.cmd(':qa')
end, {})

-- JQ formats JSON in the current buffer
vim.api.nvim_create_user_command('JQ', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.args or '.'
  util.RunCommand('jq', input, args)
end, { nargs = '*', bang = true })

-- YQ formats YAML in the current buffer
vim.api.nvim_create_user_command('YQ', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.args or '.'
  util.RunCommand('yq', input, args)
end, { nargs = '*', bang = true })

vim.api.nvim_create_user_command('DiagnosticsOpen', function() vim.diagnostic.open_float() end, {})

local resize = require('resize')

vim.api.nvim_create_user_command('Resize', function(opts)
  if #opts.fargs ~= 2 then
    print("Usage: :Resize <direction> <amount>")
    return
  end
  local direction = opts.fargs[1]
  local amount = tonumber(opts.fargs[2])
  resize.resize(direction, amount)
end, { desc = 'Resize window', nargs = '+' })

vim.api.nvim_create_user_command('ResizeMode', function()
  local resizer = require('resize').Resizer:new({
    relative_resizing = true,
  })
  resizer:start()
end, { desc = 'Start relative resize mode', count = true })
