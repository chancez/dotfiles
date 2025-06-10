local M = {}

function M.ReplaceBufferLines(content)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
end

function M.ReplaceBufferString(content)
  M.ReplaceBufferLines(vim.split(content, '\n'))
end

function M.GetBufferLines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

function M.GetBufferString()
  return table.concat(M.GetBufferLines(), '\n')
end

function M.RunCommand(binary, input, args)
  local cmd = {binary, args}

  vim.system(cmd, { stdin = input, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        M.ReplaceBufferString(result.stdout)
      else
        local cmd_str = table.concat(cmd, ' ')
        vim.api.nvim_echo({ { string.format("Error running %q: %s", cmd_str, result.stderr) } }, false, { err = true })
      end
    end)
  end)
end

return M
