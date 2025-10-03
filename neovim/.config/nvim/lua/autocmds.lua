local util = require 'util'

function HighlightWhitespace()
  vim.cmd [[
    highlight ExtraWhitespace guibg=red
    match ExtraWhitespace /\s\+$/
    autocmd BufWinEnter <buffer> match ExtraWhitespace /\s\+$/
    autocmd InsertEnter <buffer> match ExtraWhitespace /\s\+\%#\@<!$/
    autocmd InsertLeave <buffer> match ExtraWhitespace /\s\+$/
  ]]
end

local whitespaceIgnoreFileTypes = {
  'terminal',
  'toggleterm',
  'lazy',
  'mcphub',
  'markdown',
  'help',
  'k8s_*',
  'blink-cmp-menu',
}

vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = '*',
  callback = function()
    if vim.tbl_contains(whitespaceIgnoreFileTypes, vim.bo.filetype) then
      return
    end
    HighlightWhitespace()
  end
})

function StripTrailingWhitespace()
  -- Get all lines in the buffer
  local lines = util.GetBufferLines()
  local changed = false

  for i, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    if stripped ~= line then
      lines[i] = stripped
      changed = true
    end
  end

  if changed then
    util.ReplaceBufferLines(lines)
  end
end

function ToggleStripTrailingWhitespace()
  vim.b.noStripWhitespace = not vim.b.noStripWhitespace
  local status = vim.b.noStripWhitespace and "disabled" or "enabled"
  print("StripTrailingWhitespace on save for this buffer " .. status)
end

vim.api.nvim_create_user_command('ToggleStripTrailingWhitespace', ToggleStripTrailingWhitespace,
  { desc = "Toggle stripping trailing whitespace on save for this buffer" })

-- strip trailing whitespace
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
  pattern = '*',
  callback = function()
    -- Only strip if the b:noStripWhitespace variable isn't set
    if not vim.b.noStripWhitespace then
      StripTrailingWhitespace()
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd({ 'TextYankPost' }, {
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 300 })
  end,
})
