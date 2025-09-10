local util = require 'util'

-- Open help in a new tab
vim.api.nvim_create_user_command('Helptab', ':help <args> | wincmd T', { nargs = 1, complete = 'help' })

-- Quit all buffers and delete the current session
vim.api.nvim_create_user_command('Qas', function()
  vim.cmd(':silent AutoSession delete')
  vim.cmd(':AutoSession disable')
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
