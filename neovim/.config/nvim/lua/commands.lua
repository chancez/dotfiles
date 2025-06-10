local util = require 'util'

-- Open help in a new tab
vim.api.nvim_create_user_command('Helptab', ':help <args> | wincmd T', { nargs = 1, complete = 'help' })

-- Quit all buffers and delete the current session
vim.api.nvim_create_user_command('Qas', function ()
  vim.cmd(':SessionDelete')
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

vim.api.nvim_create_user_command('DiagnosticsOpen', function() vim.diagnostic.open_float() end , {})

-- dap commands

-- dap-go
local dapGo = require('dap-go')
vim.api.nvim_create_user_command('DapGoTest', function() dapGo.debug_test() end, { bang = true })

-- dap-ui
local dapUI = require('dapui')
vim.api.nvim_create_user_command('DapUIOpen', function() dapUI.open({reset=true}) end, { bang = true })
vim.api.nvim_create_user_command('DapUIClose', function() dapUI.close() end, { bang = true })
vim.api.nvim_create_user_command('DapUIToggle', function() dapUI.toggle() end, { bang = true })
vim.api.nvim_create_user_command('DapUIEval', function() dapUI.eval() end, { bang = true })

-- neotest
local neotest = require('neotest')
vim.api.nvim_create_user_command('TestNearest', function() neotest.run.run() end, { bang = true })
vim.api.nvim_create_user_command('TestFile', function() neotest.run.run(vim.fn.expand("%")) end, { bang = true })
vim.api.nvim_create_user_command('TestDirectory', function() neotest.run.run(vim.fn.expand("%:p:h")) end, { bang = true })
vim.api.nvim_create_user_command('TestSuite', function() neotest.run.run(vim.fn.getcwd()) end, { bang = true })
vim.api.nvim_create_user_command('TestOpen', function() neotest.output.toggle() end, { bang = true })
vim.api.nvim_create_user_command('TestOutput', function() neotest.output_panel.toggle() end, { bang = true })
vim.api.nvim_create_user_command('TestSummary', function() neotest.summary.toggle() end, { bang = true })
