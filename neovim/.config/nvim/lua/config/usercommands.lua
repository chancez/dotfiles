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

-- Runs a command on the buffer, visual selection (characterwise or linewise), or whole buffer.
local function run_filter_command(binary, cmd)
  local args = cmd.fargs or {}
  if #args == 0 then
    args = { '.' }
  end
  if cmd.range == 2 then
    local mode = vim.fn.visualmode()
    if mode == 'v' then
      -- Characterwise visual selection
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")
      local start_row = start_pos[2] - 1
      local start_col = start_pos[3] - 1
      local end_row = end_pos[2] - 1
      local end_col = end_pos[3]
      -- Clamp end_col to actual line length for end-of-line selections
      local end_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ''
      if end_col > #end_line then
        end_col = #end_line
      end
      util.ReplaceTextWithCommandOutput(binary, args, start_row, start_col, end_row, end_col)
    else
      -- Linewise visual selection
      local input = vim.api.nvim_buf_get_lines(0, cmd.line1 - 1, cmd.line2, false)
      util.ReplaceRangeWithCommandOutput(binary, args, input, cmd.line1, cmd.line2)
    end
  else
    local input = util.GetBufferLines()
    util.ReplaceBufferWithCommandOutput(binary, args, input)
  end
end

-- JQ formats JSON in the current buffer or visual selection
vim.api.nvim_create_user_command('JQ', function(cmd)
  run_filter_command('jq', cmd)
end, { nargs = '*', bang = true, range = true })

-- YQ formats YAML in the current buffer or visual selection
vim.api.nvim_create_user_command('YQ', function(cmd)
  run_filter_command('yq', cmd)
end, { nargs = '*', bang = true, range = true })

-- Replace the current buffer with the output of a shell command
vim.api.nvim_create_user_command('Cmd', function(cmd)
  local input = util.GetBufferLines()
  local args = cmd.fargs or {}
  util.ReplaceBufferWithCommandOutput(args[1], vim.list_slice(args, 2), input)
end, { nargs = '+', complete = 'shellcmdline' })

vim.api.nvim_create_user_command('DiagnosticsOpen', function() vim.diagnostic.open_float() end, {})

-- Trace a value one hop "up" toward its origin. With a count, repeat that many
-- times, stopping early at any branch point (multiple call sites) or origin.
vim.api.nvim_create_user_command('TraceUp', function(cmd)
  require('config.trace').trace_up_n(cmd.count > 0 and cmd.count or 1)
end, { count = true, desc = "Trace a value one hop up toward its origin (accepts a count)" })

-- Trace a value all the way to its origin, recording the path into a "Trace"
-- quickfix list. Auto-hops until an origin or a branch point; a count caps hops.
vim.api.nvim_create_user_command('TraceOrigin', function(cmd)
  require('config.trace').trace_up_n(cmd.count > 0 and cmd.count or 1000, { quickfix = true })
end, { count = true, desc = "Trace a value to its origin, recording the path into a quickfix list" })

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

-- Send diagnostics to quickfix list
vim.api.nvim_create_user_command('DiagnosticsQF', function()
  vim.diagnostic.setqflist()
  vim.cmd('copen')
end, {})

-- Close all buffers and tabs
vim.api.nvim_create_user_command('WipeSession', function()
  -- Close all other tabs
  vim.cmd(':silent tabonly')
  -- Close all buffers
  vim.cmd(':silent %bd')
end, { desc = "Close all open tabs and buffers and delete the current session." })

-- Add a helper to run MasonInstall for all the lsps configured
vim.api.nvim_create_user_command('MasonInstallAll', function()
  local servers = require("plugins.configs.lspconfig").auto_install_servers
  local registry = require "mason-registry"
  local server_mapping = require("mason-lspconfig.mappings").get_mason_map()
  local mason_api = require "mason.api.command"

  local packages_to_install = {}
  for _, server in ipairs(servers) do
    -- Convert lspconfig name to mason package name
    local package_name = server_mapping.lspconfig_to_package[server]
    local pkg = registry.get_package(package_name)
    -- Check if the package is already installed or being installed
    if not pkg:is_installed() and not pkg:is_installing() then
      table.insert(packages_to_install, package_name)
    end
  end

  if #packages_to_install == 0 then
    print("All LSP servers are already installed.")
    return
  end

  print("Installing missing LSP servers: " .. table.concat(packages_to_install, ", "))
  mason_api.MasonInstall(packages_to_install)
  print("Finished installing LSP servers.")
end, { desc = "" })

-- Yank current file path to clipboard
vim.api.nvim_create_user_command('YankFilePath', function()
  local file_path = vim.fn.expand('%')
  vim.fn.setreg('+', file_path)
  print('Yanked file path: ' .. file_path)
end, { desc = "Yank the current file's absolute path to the clipboard." })

-- Yank YAML value at cursor with its full key path
vim.api.nvim_create_user_command('YankYAMLText', function()
  require('config.yaml').yank_yaml_text('+')
end, { desc = "Yank the YAML value at cursor with its full key path" })

-- Yank dot-separated YAML key path at cursor (e.g. foo.bar.baz)
vim.api.nvim_create_user_command('YankYAMLKeyPath', function()
  require('config.yaml').yank_key_path('+')
end, { desc = "Yank the dot-separated YAML key path at cursor" })

-- Print YAML value at cursor with its full key path
vim.api.nvim_create_user_command('PrintYAMLText', function()
  local text = require('config.yaml').get_yaml_text()
  if text then
    print(text)
  end
end, { desc = "Print the YAML value at cursor with its full key path" })

-- Print dot-separated YAML key path at cursor
vim.api.nvim_create_user_command('PrintYAMLKeyPath', function()
  local path = require('config.yaml').get_key_path()
  if path then
    print(path)
  end
end, { desc = "Print the dot-separated YAML key path at cursor" })
