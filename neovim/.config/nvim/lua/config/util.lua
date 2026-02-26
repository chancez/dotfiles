local M = {}

function M.ReplaceBufferLines(content)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
end

function M.ReplaceBufferString(content)
  local lines = vim.split(content, '\n')
  -- If the content ends with a newline, remove the last empty line added by split
  if lines[#lines] == '' then
    table.remove(lines, #lines)
  end
  M.ReplaceBufferLines(lines)
end

function M.GetBufferLines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

function M.GetBufferString()
  return table.concat(M.GetBufferLines(), '\n')
end

-- Runs a command with given input and replaces the current buffer with the command's output.
-- @param binary (string) The command to run.
-- @param input (string) The input to pass to the command's stdin.
-- @param args (table|string) Additional arguments to pass to the command.
function M.ReplaceBufferWithCommandOutput(binary, args, input)
  if type(args) == 'string' then
    args = { args }
  end
  if args == nil then
    args = {}
  end
  local cmd = { binary }
  vim.list_extend(cmd, args)

  vim.system(cmd, { stdin = input, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        M.ReplaceBufferString(result.stdout)
      else
        local cmd_str = table.concat(cmd, ' ')
        vim.api.nvim_echo({ { string.format("Error running %q: %s", cmd_str, result.stderr) } }, false,
          { err = true })
      end
    end)
  end)
end

function M.table_concat(t1, t2)
  local result = {}
  vim.list_extend(result, t1)
  vim.list_extend(result, t2)
  return result
end

-- Map a command to a keybinding. The command must already be defined.
function M.map_user_command(cmd, lhs, bufnr)
  local rhs = '<cmd>' .. cmd .. '<CR>'
  local mode = { 'n', 'v' }
  vim.keymap.set(mode, lhs, rhs, { desc = cmd, silent = true, buffer = bufnr or 0 })
end

-- Define a command and map it to a keybinding
function M.map_and_define_user_command(name, lhs, command, bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_create_user_command(bufnr, name, command, { desc = name })
  M.map_user_command(name, lhs, bufnr)
end

function M.get_qf_filelist(cwd)
  local Path = require "plenary.path"
  if cwd == nil then
    cwd = vim.fn.getcwd()
  end
  local qflist = vim.fn.getqflist()

  local filelist = {}
  local unique_files = {}
  for _, item in ipairs(qflist) do
    local file = vim.api.nvim_buf_get_name(item.bufnr)
    if file and vim.fn.filereadable(file) == 1 then
      local relpath = Path:new(file):make_relative(cwd)
      if not unique_files[relpath] then
        unique_files[relpath] = true
        table.insert(filelist, relpath)
      end
    end
  end
  return filelist
end

function M.get_buf_filelist(cwd)
  local Path = require "plenary.path"
  local buflist = vim.fn.getbufinfo({ buflisted = 1 })

  local filelist = {}
  local unique_files = {}
  for _, buf in ipairs(buflist) do
    local file = vim.api.nvim_buf_get_name(buf.bufnr)
    if file and vim.fn.filereadable(file) == 1 then
      local relpath = Path:new(file):make_relative(cwd)
      if not unique_files[relpath] then
        unique_files[relpath] = true
        table.insert(filelist, relpath)
      end
    end
  end
  return filelist
end

return M
