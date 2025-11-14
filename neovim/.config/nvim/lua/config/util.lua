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

return M
