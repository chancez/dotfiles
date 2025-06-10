local wk = require("which-key")

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

wk.add({
  {'<leader>w', ':WhichKey<CR>', desc = 'Open WhichKey', mode='n', { silent = true }},

  {'<leader>ev', ':e $MYVIMRC<CR>', desc = 'Edit neovim init.lua', mode='n'},

  -- Get rid of annoying mistakes
  {'WQ', 'wq', mode='c'},
  {'wQ', 'wq', mode='c'},
  {';', ':', mode={'n', 'v'}},
  {';;', ';', mode={'n', 'v'}},
  {',,', ',', mode={'n', 'v'}},
  {';', ':', mode='n'},

  -- window movement
  {'<A-h>', '<c-w>h', mode='n'},
  {'<A-j>', '<c-w>j', mode='n'},
  {'<A-k>', '<c-w>k', mode='n'},
  {'<A-l>', '<c-w>l', mode='n'},

  -- this maps leader + esc to exit terminal mode
  {'<leader><Esc>', '<C-\\><C-n>', mode='t'},
  -- This makes navigating windows the same no matter if they are displaying
  -- a normal buffer or a terminal buffer
  -- Move around windows in terminal
  {'<A-h>', '<C-\\><C-n><C-w>h', mode='t'},
  {'<A-j>', '<C-\\><C-n><C-w>j', mode='t'},
  {'<A-k>', '<C-\\><C-n><C-w>k', mode='t'},
  {'<A-l>', '<C-\\><C-n><C-w>l', mode='t'},

  -- Buffer movement
  {'<m-]>', ':bnext<CR>', desc = 'Next buffer', mode='n'},
  {'<m-[>', ':bprev<CR>', desc = 'Previous buffer', mode='n'},

  -- Indenting Move to next/previous line with same indentation
  {'<M-,>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%<' . line('.') . 'l\S', 'be')<CR>]], desc = 'Move to next line with same indentation', mode='n'},
  {'<M-.>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%>' . line('.') . 'l\S', 'e')<CR>]], desc = 'Move to previous line with same indentation', mode='n'},

  -- Wrapped lines goes down/up to next row, rather than next line in file.
  {'j', 'gj', mode='n'},
  {'k', 'gk', mode='n'},

  -- Make Y behave like other capitals
  {'Y', 'y$', mode='n'},

  -- Reselect visual block after indent
  {'<', '<gv', mode='v'},
  {'>', '>gv', mode='v'},

  -- Escape insert by hitting jj
  {'jj', '<ESC>', mode='i'},

  -- Folds
  {'<space>', 'za', desc = 'Toggle folds', mode='n'},
  --
  -- Clear the current search highlights
  {'<leader>/', ':nohlsearch<CR>', desc = 'Clear search hightlights', mode='n', { silent = true }},
  -- clear hlsearch on redraw
  {'<C-L>', ':nohlsearch<CR><C-L>', desc = 'Clear search hightlights', mode='n'},

  -- set "gf" to create a new file if the one under the cursor does not exist
  {'gf', function() GoToFile() end, desc = 'Go to file under cursor', mode={'n'}},

  -- vim-maximizer
  {'<c-w>0', ':MaximizerToggle<CR>', mode={'n'}},

  -- easy align
  {'ga', '<Plug>(EasyAlign)', desc = 'Easy align', mode={'n', 'x'}},

  -- vim commentary
  {'<M-/>', ':Commentary<CR>', mode={'n', 'v'}, { silent = true }},

  -- tagbar
  {'<m-e>', ':TagbarToggle<CR>', mode='nvo', { silent = true }},
})

-- Testing with dap
wk.add({
  silent = true,
  mode = 'nvo',
  {'gtn', ':TestNearest<CR>'},
  {'gtf', ':TestFile<CR>'},
  {'gtd', ':TestDirectory<CR>'},
  {'gts', ':TestSuite<CR>'},
  {'gto', ':TestOpen<CR>'},
  {'gtO', ':TestOutput<CR>'},
  {'gtS', ':TestSummary<CR>'},

})

-- Diagnostic keymaps/commands
wk.add({
  mode =  'n',
  silent = true,
  {'[d', function() vim.diagnostic.goto_prev() end, desc = 'Diagnostics goto previous'},
  {']d', function() vim.diagnostic.goto_next() end, desc = 'Diagnostics goto next'},
  {'<leader>q', function() vim.diagnostic.setloclist() end, desc = 'Diagnostics loclist'},
})
