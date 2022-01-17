-- bootstrap packer
local packer_exists = pcall(vim.cmd, [[packadd packer.nvim]])
if not packer_exists then
  local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/opt/packer.nvim'
  vim.fn.system('git clone --depth 1 https://github.com/wbthomason/packer.nvim ' .. install_path)
  vim.cmd [[packadd packer.nvim]]
end

local packer = require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- performance
  use 'lewis6991/impatient.nvim'

  -- visual
  use 'navarasu/onedark.nvim'
  use 'norcalli/nvim-colorizer.lua'
  use 'preservim/tagbar'
  use 'scrooloose/nerdtree'

  use {
    'nvim-lualine/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}
  }

  -- search
  use {
    'nvim-telescope/telescope.nvim',
    requires = {
      'nvim-lua/popup.nvim',
      'nvim-telescope/telescope-frecency.nvim',
      'nvim-lua/plenary.nvim',
    },
  }

  -- highlights
  use {
    'nvim-treesitter/nvim-treesitter',
    requires = {
      'nvim-treesitter/nvim-treesitter-refactor',
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    run = ':TSUpdate',
  }

  -- LSP
  use 'neovim/nvim-lspconfig'
  use 'ray-x/lsp_signature.nvim'
  use 'onsails/lspkind-nvim'

  -- autocomplete
  use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
  use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp

  -- snippets
  use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
  use "rafamadriz/friendly-snippets"
  use 'L3MON4D3/LuaSnip' -- Snippets plugin

  -- utilities that leverage vim verbs
  use 'tpope/vim-repeat'
  use 'tpope/vim-unimpaired'
  use 'tpope/vim-surround'

  -- utilities
  use 'tpope/vim-commentary'
  use 'tpope/vim-eunuch'

  -- multicursor support like sublime text
  use 'terryma/vim-multiple-cursors'

  -- Prettifies
  use 'junegunn/vim-easy-align'

  -- git
  use 'tpope/vim-fugitive'
  use 'tpope/vim-git'
  --
  -- language/syntax integrations
  use 'jjo/vim-cue'
  use 'fatih/vim-go'

  use 'google/vim-jsonnet'
  use 'chr4/nginx.vim'
  use 'hashivim/vim-terraform'
end)
if not packer_exists then packer.sync() end -- install on first run

-- misc global opts
local settings = {
  'set mouse=a',
  'set colorcolumn=80,100',
  'set cursorline',
  'set cursorcolumn',
  'set completeopt=menu,menuone,longest,noinsert,noselect',
  'set cpoptions=ces$',
  'set ffs=unix,dos',
  'set fillchars=vert:·',
  'set foldopen=block,insert,jump,mark,percent,quickfix,search,tag,undo',
  'set autoread',
  'set hidden',
  'set scrolloff=5', -- Begin scrolling when cursor is at 5 from the edge
  'set lazyredraw',
  'set list listchars=tab:·\\ ',
  'set noerrorbells',
  'set noshowmode',
  'set number',
  'set shellslash',
  'set showfulltag',
  'set hlsearch', -- Highlight as you search.
  'set ignorecase', -- Ignore case when searching
  'set showmatch', -- highlight matching [{()}]
  'set incsearch', --  Searches as you type.
  'set smartcase', -- if case seems to matter use it
  'set showmode',
  'set synmaxcol=2048',
  'set t_Co=256',
  'set title',
  'set tabstop=2 softtabstop=2 shiftwidth=2 expandtab copyindent',
  'set visualbell',
  'set wrap',
  'set visualbell',
  'set wrapscan',
  'set termguicolors',
  'set clipboard=unnamed',
  'set undofile',
  -- Allow undos and history to be persistant
  'set undolevels=1000',
  'set history=1000',
  -- When you set g:easytags_dynamic_files to 2 new tags files are created in the same directory as the file you're editing.
  -- If you want the tags files to be created in your working directory instead then change Vim's 'cpoptions' option to include the lowercase letter 'd'.
  'set tags=./tags;,tags;',
  'set cpoptions=aAceFsBd_',
  -- show the effects of a command incrementally as you type.
  'set inccommand=nosplit',
  [[set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case]],
}
for _, setting in ipairs(settings) do vim.cmd(setting) end

-- leader
vim.g.mapleader = ','

vim.g.python_host_prog = '~/.asdf/shims/python2'
vim.g.python3_host_prog = '~/.asdf/shims/python3'

-- mapping functions
local cmap        = function(lhs, rhs) vim.api.nvim_set_keymap('c', lhs, rhs, {}) end
local nmap        = function(lhs, rhs) vim.api.nvim_set_keymap('n', lhs, rhs, {}) end
local vmap        = function(lhs, rhs) vim.api.nvim_set_keymap('v', lhs, rhs, {}) end
local xmap        = function(lhs, rhs) vim.api.nvim_set_keymap('v', lhs, rhs, {}) end
local map       = function(lhs, rhs) vim.api.nvim_set_keymap('', lhs, rhs, {}) end
local smap       = function(lhs, rhs) vim.api.nvim_set_keymap('', lhs, rhs, { silent = true}) end
local snmap       = function(lhs, rhs) vim.api.nvim_set_keymap('n', lhs, rhs, { silent = true}) end
local vnoremap    = function(lhs, rhs) vim.api.nvim_set_keymap('v', lhs, rhs, { noremap = true }) end
local nnoremap    = function(lhs, rhs) vim.api.nvim_set_keymap('n', lhs, rhs, { noremap = true }) end
local tnoremap    = function(lhs, rhs) vim.api.nvim_set_keymap('t', lhs, rhs, { noremap = true }) end
local inoremap    = function(lhs, rhs) vim.api.nvim_set_keymap('i', lhs, rhs, { noremap = true }) end
local bufsnoremap = function(lhs, rhs) vim.api.nvim_buf_set_keymap(0, 'n', lhs, rhs, { noremap = true, silent = true }) end
local lspremap    = function(keymap, fn_name) bufsnoremap(keymap, '<cmd>lua vim.lsp.' .. fn_name .. '()<CR>') end

-- autocmds
local function autocmd(group, cmds, clear)
  clear = clear == nil and false or clear
  if type(cmds) == 'string' then cmds = {cmds} end
  vim.cmd('augroup ' .. group)
  if clear then vim.cmd [[au!]] end
  for _, c in ipairs(cmds) do vim.cmd('autocmd ' .. c) end
  vim.cmd [[augroup END]]
end

-- language server

-- Add neovim lua files to runtime path for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

local lspcfg = {
  gopls       = {
    binary         = 'gopls',
    -- Unneeded, already handled
    format_on_save = nil,
    settings = {
      Gopls = {
        completeUnimported = true,
        analyses = {
          unusedparams = true,
        },
      },
    },
  },
  sumneko_lua = {
    binary         = 'lua-language-server',
    format_on_save = nil,
    settings = {
      Lua = {
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = {'vim'},
        },
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = vim.api.nvim_get_runtime_file("", true),
        },
      },
    },
  },
}

local lsp_keymaps = {
  {capability = 'declaration',      mapping = 'gd',    command = 'buf.declaration'     },
  {capability = 'implementation',   mapping = 'gD',    command = 'buf.implementation'  },
  {capability = 'goto_definition',  mapping = '<c-]>', command = 'buf.definition'      },
  {capability = 'type_definition',  mapping = '1gD',   command = 'buf.type_definition' },
  {capability = 'hover',            mapping = 'K',     command = 'buf.hover'           },
  {capability = 'signature_help',   mapping = '<c-k>', command = 'buf.signature_help'  },
  {capability = 'find_references',  mapping = 'gr',    command = 'buf.references'      },
  {capability = 'document_symbol',  mapping = 'g0',    command = 'buf.document_symbol' },
  {capability = 'workspace_symbol', mapping = 'gW',    command = 'buf.workspace_symbol'},
}

local custom_lsp_attach = function(client)
  local opts = lspcfg[client.name]

  -- autocommplete
  vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- format on save
  if opts['format_on_save'] ~= nil then
    autocmd(client.name, {
      'ButWritePre' .. opts['format_on_save'] .. ' :lua vim.lsp.buf.formatting_sync(nil, 1000)',
    }, true)
  end

  -- conditional keymaps
  for _, keymap in ipairs(lsp_keymaps) do
    if client.resolved_capabilities[keymap.capability] then
      lspremap(keymap.mapping, keymap.command)
    end
  end

  -- unconditional keymaps
  lspremap('gl', 'diagnostic.show_line_diagnostics')
end

-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- lspconfig
-- only setup lsp clients for binaries that exist
local lsp = require('lspconfig')
for srv, opts in pairs(lspcfg) do
  if vim.fn.executable(opts['binary']) then
    lsp[srv].setup {
      on_attach = custom_lsp_attach,
      settings = opts.settings,
      capabilities = capabilities,
    }
  end
end

-- lsp signature
require('lsp_signature').setup {
  zindex = 50,
  bind = true, -- This is mandatory, otherwise border config won't get registered.
  handler_opts = {
    border = "rounded"
  },
  toggle_key = "<C-l>",
}

-- luasnip setup
local luasnip = require 'luasnip'
luasnip.config.set_config {
    history = true,
    updateevents = "TextChanged,TextChangedI"
}
require("luasnip/loaders/from_vscode").load()

-- nvim-cmp setup
local cmp = require 'cmp'

cmp.setup {
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-k>'] = cmp.mapping.select_prev_item(),
    ['<C-j>'] = cmp.mapping.select_next_item(),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end,
    ['<S-Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end,
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'buffer' },
    { name = 'luasnip' },
    { name = 'path' },
  },
}

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})

-- mappings
nnoremap('<leader>ev', ':e $MYVIMRC<CR>')
nnoremap('<leader>sv', ':source $MYVIMRC<CR>')

-- Get rid of annoying mistakes
cmap('WQ', 'wq')
cmap('wQ', 'wq')
nnoremap(';', ':')
vnoremap(';', ':')
nnoremap(';;', ';')
vnoremap(';;', ';')
nnoremap(',,', ',')
vnoremap(',,', ',')
nnoremap(';', ':')

-- window movement
nmap('<A-h>', '<c-w>h')
nmap('<A-j>', '<c-w>j')
nmap('<A-k>', '<c-w>k')
nmap('<A-l>', '<c-w>l')

-- this maps leader + esc to exit terminal mode
tnoremap('<leader><Esc>', '<C-\\><C-n>')
-- This makes navigating windows the same no matter if they are displaying
-- a normal buffer or a terminal buffer
-- Move around windows in terminal
tnoremap('<A-h>', '<C-\\><C-n><C-w>h')
tnoremap('<A-j>', '<C-\\><C-n><C-w>j')
tnoremap('<A-k>', '<C-\\><C-n><C-w>k')
tnoremap('<A-l>', '<C-\\><C-n><C-w>l')

-- Wrapped lines goes down/up to next row, rather than next line in file.
nnoremap('j', 'gj')
nnoremap('k', 'gk')

-- Make Y behave like other capitals
-- Reselect visual block after indent
nnoremap('Y', 'y$')

vnoremap('<', '<gv')
vnoremap('>', '>gv')

-- Escape insert by hitting jj
inoremap('jj', '<ESC>')
-- Clear the current search highlights
snmap('<leader>/', ':nohlsearch<CR>')
-- clear hlsearch on redraw
nnoremap('<C-L>', ':nohlsearch<CR><C-L>')

-- easy align
xmap('ga', '<Plug>(EasyAlign)')
nmap('ga', '<Plug>(EasyAlign)')

-- vim commentary
snmap('<M-/>', ':Commentary<CR>')
vmap('<M-/>', ':Commentary<CR>')

-- nerdtree
map('<C-e>', ':NERDTreeToggle<CR>:NERDTreeMirror<CR>')

-- tagbar (requires remapped key in terminal emulator for "ctrl-shift-e" to work)
map('<m-e>', ':TagbarToggle<CR>')

-- vim-go
snmap('<leader>gb', ':GoBuild<cr>')

-- clipboard
if vim.fn.has('unnamedplus') then vim.o.clipboard = 'unnamedplus' else vim.o.clipboard = 'unnamed' end

-- colorscheme
require('onedark').setup {
  style = 'warm'
}
require('onedark').load()

-- lualine
require'lualine'.setup {
  options = {theme = 'onedark'},
  tabline = {
    lualine_a = {
      {
        'buffers',
        mode = 2,
      }
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {'tabs'}
  }
}

-- setup colorizer
require('colorizer').setup()

-- telescope
require('telescope').setup{
  defaults = {
    mappings = {
      i = {
        ["<C-k>"] = "move_selection_previous",
        ["<C-j>"] = "move_selection_next",
        ["<M-k>"] = "preview_scrolling_up",
        ["<M-j>"] = "preview_scrolling_down",
        ["<C-u>"] = false,
        ["<C-d>"] = false,
      },
      n = {
        ["<C-k>"] = "move_selection_previous",
        ["<C-j>"] = "move_selection_next",
      },
    }
  }
}

nnoremap('<c-p>', "<cmd>lua require('telescope.builtin').find_files()<cr>")
nnoremap('<m-o>', "<cmd>lua require('telescope.builtin').buffers()<cr>")
nnoremap('<m-p>', "<cmd>lua require('telescope.builtin').tags()<cr>")
nnoremap('<leader>ff', "<cmd>lua require('telescope.builtin').find_files()<cr>")
nnoremap('<leader>fg', "<cmd>lua require('telescope.builtin').live_grep()<cr>")
nnoremap('<leader>fb', "<cmd>lua require('telescope.builtin').buffers()<cr>")
nnoremap('<leader>fh', "<cmd>lua require('telescope.builtin').help_tags()<cr>")

-- setup treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained",
  highlight = { enable = true },
}

-- show trailing whitespace https://vim.fandom.com/wiki/Highlight_unwanted_spaces
vim.cmd([[
  autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
  match ExtraWhitespace /\s\+$/
  autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
  autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
  autocmd InsertLeave * match ExtraWhitespace /\s\+$/
  autocmd BufWinLeave * call clearmatches()
]])

-- strip trailing whitespace
vim.cmd([[
fun! StripTrailingWhitespace()
    " Only strip if the b:noStripeWhitespace variable isn't set
    if exists('b:noStripWhitespace')
        return
    endif
    %s/\s\+$//e
endfun
autocmd BufWritePre * call StripTrailingWhitespace()
]])

-- always go into insert mode when entering a terminal
autocmd('TerminalEnter', {
  [[BufWinEnter,WinEnter term://* startinsert]]
}, true)

vim.cmd([[autocmd BufWinEnter,WinEnter term://* startinsert]])
  --
-- custom commands
vim.cmd(
[[
command! -nargs=* -complete=file TermBelow call TermFunc('below', 'new', '15', <f-args>)
command! -nargs=* -complete=file TermBottom call TermFunc('bo', 'new', '15', <f-args>)
command! -nargs=* -complete=file TermSizedBottom call TermFunc('bo', 'new', <f-args>)

function! TermFunc(pos, direction, size, ...)
    execute a:pos " " . a:size . a:direction . " "
    execute 'terminal ' . join(a:000)
    setlocal winfixheight
endfunction
]]
)