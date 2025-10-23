-- misc global opts
vim.opt.spell = true
vim.opt.mouse = 'a'
-- Configured via autocmds on the active window
-- vim.opt.colorcolumn = '80,100'
-- vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true
vim.opt.completeopt = 'menu,menuone,longest,noinsert,noselect'
vim.opt.autoread = true
vim.opt.hidden = true
vim.opt.scrolloff = 5 -- Begin scrolling when cursor is at 5 from the edge
vim.opt.lazyredraw = true
vim.opt.errorbells = false
vim.opt.number = true
-- vim.opt.relativenumber = true
-- vim.opt.statuscolumn = '%s%{&nu?v:lnum:""}%=%{&rnu?" ".v:relnum:""}'
vim.opt.showfulltag = true
vim.opt.hlsearch = true   -- Highlight as you search.
vim.opt.ignorecase = true -- Ignore case when searching
vim.opt.showmatch = true  -- highlight matching [{()}]
vim.opt.incsearch = true  --  Searches as you type.
vim.opt.smartcase = true  -- if case seems to matter use it
vim.opt.showmode = true
vim.opt.synmaxcol = 2048
vim.opt.title = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.copyindent = true
vim.opt.wrap = true
vim.opt.visualbell = true
vim.opt.wrapscan = true
vim.opt.termguicolors = true
vim.opt.undofile = true
-- Allow undos and history to be persistant
vim.opt.undolevels = 1000
vim.opt.history = 1000
vim.opt.backup = true
vim.opt.backupdir = os.getenv('HOME') .. '/.local/share/nvim/backup'
-- show the effects of a command incrementally as you type.
vim.opt.inccommand = 'nosplit'
vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'
vim.opt.signcolumn = 'yes'
-- Look for tags in the project directory
vim.opt.tags = 'tags;'

-- folds
--Specifies for which type of commands folds will be opened, if the
vim.opt.foldopen = 'block,insert,jump,mark,percent,quickfix,search,tag,undo'
vim.opt.foldenable = true
vim.opt.foldlevelstart = 10 -- open most folds by default
vim.opt.foldnestmax = 10    -- 10 nested fold max
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"

-- Splits
vim.opt.splitright = true

-- Load .nvmrc
vim.opt.exrc = true

-- https://github.com/rmagatti/auto-session?tab=readme-ov-file#recommended-sessionoptions-config
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.cmd [[ packadd cfilter ]]

-- indent-blankline
vim.opt.list = true
vim.opt.listchars:append("space:⋅")

-- clipboard
if vim.fn.has('unnamedplus') then
  vim.o.clipboard = 'unnamedplus'
else
  vim.o.clipboard = 'unnamed'
end

-- leader
vim.g.mapleader = ','

-- Silence writes via netrw
vim.g.netrw_silent = 1
