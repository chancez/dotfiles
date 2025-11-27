local util = require('config.util')

-- Open help in a new tab
vim.api.nvim_create_user_command('HelpTab', ':help <args> | wincmd T', { nargs = 1, complete = 'help' })
vim.api.nvim_create_user_command('HelpVert', ':vert botright help <args>', { nargs = 1, complete = 'help' })

-- Quit all buffers and delete the current session
vim.api.nvim_create_user_command('Qas', function(opts)
  vim.cmd(':silent AutoSession delete')
  vim.cmd(':silent AutoSession disable')
  local quit_cmd = opts.bang and ':qa!' or ':qa'
  vim.cmd(quit_cmd)
end, {
  bang = true,
})

-- JQ formats JSON in the current buffer
vim.api.nvim_create_user_command('JQ', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.fargs or {}
  if #args == 0 then
    args = { '.' }
  end
  util.ReplaceBufferWithCommandOutput('jq', args, input)
end, { nargs = '*', bang = true })

-- YQ formats YAML in the current buffer
vim.api.nvim_create_user_command('YQ', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.fargs or {}
  if #args == 0 then
    args = { '.' }
  end
  util.ReplaceBufferWithCommandOutput('yq', args, input)
end, { nargs = '*', bang = true })

-- Replace the current buffer with the output of a shell command
vim.api.nvim_create_user_command('Cmd', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.fargs or {}
  util.ReplaceBufferWithCommandOutput(args[1], vim.list_slice(args, 2), input)
end, { nargs = '+', complete = 'shellcmdline' })

vim.api.nvim_create_user_command('DiagnosticsOpen', function() vim.diagnostic.open_float() end, {})

-- Reverse the lines of the selection in visual mode
vim.api.nvim_create_user_command('ReverseLines', function()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  -- Reverse the lines
  local reversed_lines = {}
  for i = #lines, 1, -1 do
    table.insert(reversed_lines, lines[i])
  end

  -- Set the reversed lines back to the buffer
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, reversed_lines)
end, { range = true })

-- Toggle diagnostics on and off for the current buffer
vim.api.nvim_create_user_command('ToggleDiagnostics', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled(), { bufnr = 0 })
end, {})

-- Close all buffers and tabs
vim.api.nvim_create_user_command('WipeSession', function()
  -- Close all other tabs
  vim.cmd(':tabonly')
  -- Close all buffers
  vim.cmd(':%bd')
end, { desc = "Close all open tabs and buffers and delete the current session." })
