local util = require 'util'

local event_to_pattern = {
  -- highlight trailing whitespace when we enter into a buffer
  BufWinEnter = "\\s\\+$",
  -- do not highlight trailing whitespace while inserting
  InsertEnter = "\\s\\+\\%#\\@<!$",
  -- re-highlight trailing whitespace when leaving insert mode
  InsertLeave = "\\s\\+$",
}

vim.api.nvim_set_hl(0, 'ExtraWhitespace', { bg = 'red' })

function HighlightWhitespace()
  for event, pattern in pairs(event_to_pattern) do
    vim.api.nvim_create_autocmd(event, {
      buffer = 0,
      callback = function()
        -- Delete the existing match if it exists, we only want one at a time
        if vim.w.whitespace_match then
          vim.fn.matchdelete(vim.w.whitespace_match)
        end
        vim.w.whitespace_match = vim.fn.matchadd('ExtraWhitespace', pattern)
      end,
    })
  end
end

-- Lua match patterns to ignore certain filetypes
local whitespaceIgnoreFileTypes = {
  'terminal',
  'toggleterm',
  'lazy',
  'mcphub',
  'markdown',
  'help',
  'k8s_.*',
  -- Dashes need to be escaped
  vim.pesc('blink-cmp-menu'),
  'Avante.*'
}

vim.api.nvim_create_autocmd({ 'FileType' }, {
  -- Apply to all filetypes because we will filter inside the callback since
  -- there is no way to use patterns in the FileType autocmd to do an ignore
  -- list without inverting all patterns directly
  pattern = '*',
  callback = function(ev)
    -- Check if the current filetype matches any pattern in the ignore list
    for _, pattern in ipairs(whitespaceIgnoreFileTypes) do
      if vim.bo.filetype:match('^' .. pattern .. '$') then
        return
      end
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
    if not vim.b.noStripWhitespace then
      StripTrailingWhitespace()
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd({ 'TextYankPost' }, {
  pattern = '*',
  callback = function()
    vim.hl.on_yank({ higroup = 'IncSearch', timeout = 300 })
  end,
})

-- Disable cursorline and cursorcolumn in non-active windows
vim.api.nvim_create_autocmd({ 'WinLeave' }, {
  pattern = '*',
  callback = function()
    vim.wo.cursorline = false
    vim.wo.cursorcolumn = false
    vim.wo.colorcolumn = ''
  end,
})

-- Enable cursorline and cursorcolumn in active window
vim.api.nvim_create_autocmd({ 'WinEnter' }, {
  pattern = '*',
  callback = function()
    vim.wo.cursorline = true
    vim.wo.cursorcolumn = true
    vim.wo.colorcolumn = '80,100'
  end,
})
