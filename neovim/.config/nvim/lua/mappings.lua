-- GoToFile emulates how 'gf' works in Vim.
-- It will search for the file under the cursor using the configured vim 'path' option.
-- If it exists, it will open the existing file.
-- If it does not exist, it will open a new file
-- in the first directory that exists according to the 'vim' path option (found using :finddir).
local function GoToFile()
  local cfile = vim.fn.findfile(vim.fn.expand("<cfile>"))
  if cfile == "" then
    local dir = vim.fn.finddir(vim.fn.expand("<cfile>:h"))
    local tail = vim.fn.expand("<cfile>:t")
    cfile = dir .. "/" .. tail
  end
  vim.cmd.edit(cfile)
end

local map = vim.keymap.set

map('n', '<leader>ev', ':e $MYVIMRC<CR>', { desc = 'Edit neovim init.lua' })
--
-- Get rid of annoying mistakes
map('c', 'WQ', 'wq')
map('c', 'wQ', 'wq')
map({ 'n', 'v' }, ';', ':')
map({ 'n', 'v' }, ';;', ';')
map({ 'n', 'v' }, ',,', ',')
map('n', ';', ':')

-- window movement
map('n', '<A-h>', '<c-w>h')
map('n', '<A-j>', '<c-w>j')
map('n', '<A-k>', '<c-w>k')
map('n', '<A-l>', '<c-w>l')

-- this maps leader + esc to exit terminal mode
map('t', '<leader><Esc>', '<C-\\><C-n>')
-- This makes navigating windows the same no matter if they are displaying
-- a normal buffer or a terminal buffer
-- Move around windows in terminal
map('t', '<A-h>', '<C-\\><C-n><C-w>h')
map('t', '<A-j>', '<C-\\><C-n><C-w>j')
map('t', '<A-k>', '<C-\\><C-n><C-w>k')
map('t', '<A-l>', '<C-\\><C-n><C-w>l')

-- Buffer movement
map('n', '<m-]>', ':bnext<CR>', { desc = 'Next buffer' })
map('n', '<m-[>', ':bprev<CR>', { desc = 'Previous buffer' })

-- Indenting Move to next/previous line with same indentation
map('n', '<M-,>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%<' . line('.') . 'l\S', 'be')<CR>]],
  { desc = 'Move to next line with same indentation' })
map('n', '<M-.>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%>' . line('.') . 'l\S', 'e')<CR>]],
  { desc = 'Move to previous line with same indentation' })

-- Wrapped lines goes down/up to next row, rather than next line in file.
map('n', 'j', 'gj')
map('n', 'k', 'gk')

-- Make Y behave like other capitals
map('n', 'Y', 'y$')

-- Reselect visual block after indent
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Escape insert by hitting jj
map('i', 'jj', '<ESC>')

-- Folds
map('n', '<space>', 'za', { desc = 'Toggle folds' })

-- Clear the current search highlights
map('n', '<leader>/', ':nohlsearch<CR>', { desc = 'Clear search hightlights', silent = true })
-- clear hlsearch on redraw
map('n', '<C-L>', ':nohlsearch<CR><C-L>', { desc = 'Clear search hightlights' })

-- set "gf" to create a new file if the one under the cursor does not exist
map('n', 'gf', function() GoToFile() end, { desc = 'Go to file under cursor' })

-- Diagnostics
map('n', '[d', function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = 'Diagnostics goto previous' })
map('n', ']d', function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = 'Diagnostics goto next' })
map('n', '<leader>q', function() vim.diagnostic.setloclist() end, { desc = 'Diagnostics loclist' })
