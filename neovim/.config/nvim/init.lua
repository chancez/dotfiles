-- bootstrap packer
local packer_exists = pcall(vim.cmd, [[packadd packer.nvim]])
if not packer_exists then
  local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/opt/packer.nvim'
  vim.fn.system('git clone --depth 1 https://github.com/wbthomason/packer.nvim ' .. install_path)
  vim.cmd [[packadd packer.nvim]]
end

local packer = require('packer').startup(function(use)
  -- package management
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
      {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
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
  use 'hrsh7th/cmp-cmdline' -- cmdline source
  use 'hrsh7th/cmp-nvim-lsp' -- LSP source
  use 'hrsh7th/cmp-path' -- path source
  use 'hrsh7th/cmp-buffer' -- buffer source
  use 'hrsh7th/nvim-cmp' -- Autocompletion plugin

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
  use 'junegunn/vim-easy-align'
  use 'b0o/mapx.nvim'
  use 'folke/which-key.nvim'

  -- multicursor support like sublime text
  use 'terryma/vim-multiple-cursors'

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

-- Load mapx and make it available
require'mapx'.setup { whichkey = true }
local mapx = require'mapx'

-- misc global opts
vim.opt.mouse = 'a'
vim.opt.colorcolumn = '80,100'
vim.opt.cursorline = true
vim.opt.cursorcolumn = true
vim.opt.completeopt = 'menu,menuone,longest,noinsert,noselect'
vim.opt.foldopen = 'block,insert,jump,mark,percent,quickfix,search,tag,undo'
vim.opt.autoread = true
vim.opt.hidden = true
vim.opt.scrolloff = 5 -- Begin scrolling when cursor is at 5 from the edge
vim.opt.lazyredraw = true
vim.opt.list = true
vim.opt.listchars = { tab = '· ' }
vim.opt.errorbells = false
vim.opt.number = true
vim.opt.showfulltag = true
vim.opt.hlsearch = true -- Highlight as you search.
vim.opt.ignorecase = true -- Ignore case when searching
vim.opt.showmatch = true -- highlight matching [{()}]
vim.opt.incsearch = true --  Searches as you type.
vim.opt.smartcase = true -- if case seems to matter use it
vim.opt.showmode = true
vim.opt.synmaxcol = 2048
vim.opt.title = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.copyindent = true
vim.opt.visualbell = true
vim.opt.wrap = true
vim.opt.visualbell = true
vim.opt.wrapscan = true
vim.opt.termguicolors = true
vim.opt.undofile = true
-- Allow undos and history to be persistant
vim.opt.undolevels = 1000
vim.opt.history = 1000
-- show the effects of a command incrementally as you type.
vim.opt.inccommand = 'nosplit'
vim.opt.grepprg = 'rg --vimgrep --no-heading --smart-case'

-- clipboard
if vim.fn.has('unnamedplus') then vim.o.clipboard = 'unnamedplus' else vim.o.clipboard = 'unnamed' end

-- leader
vim.g.mapleader = ','

vim.g.python_host_prog = '~/.asdf/shims/python2'
vim.g.python3_host_prog = '~/.asdf/shims/python3'

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

-- Diagnostic keymaps
mapx.group("silent", function()
  mapx.nnoremap('<leader>e', '<cmd>lua vim.diagnostic.open_float()<CR>')
  mapx.nnoremap('[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>')
  mapx.nnoremap(']d', '<cmd>lua vim.diagnostic.goto_next()<CR>')
  mapx.nnoremap('<leader>q', '<cmd>lua vim.diagnostic.setloclist()<CR>')
end)

-- LSP settings
local lspconfig = require 'lspconfig'
local on_attach = function()
  mapx.group("silent", "buffer", function()
    mapx.nnoremap('gD', '<cmd>lua vim.lsp.buf.declaration()<CR>')
    mapx.nnoremap('gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
    mapx.nnoremap('K', '<cmd>lua vim.lsp.buf.hover()<CR>')
    mapx.nnoremap('gi', '<cmd>lua vim.lsp.buf.implementation()<CR>')
    mapx.nnoremap('<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>')
    mapx.nnoremap('<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>')
    mapx.nnoremap('<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>')
    mapx.nnoremap('<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>')
    mapx.nnoremap('<leader>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>')
    mapx.nnoremap('<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>')
    mapx.nnoremap('gr', '<cmd>lua vim.lsp.buf.references()<CR>')
    mapx.nnoremap('<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>')
    mapx.nnoremap('<leader>so', [[<cmd>lua require('telescope.builtin').lsp_document_symbols()<CR>]])
  end)
  mapx.cmdbang('Format', 'lua vim.lsp.buf.formatting()')
end

-- nvim-cmp supports additional completion capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- Enable the following language servers (using defaults)
local servers = { 'clangd', 'rust_analyzer', 'pyright', 'tsserver' }
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

-- Insert runtime_path of neovim lua files for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, 'lua/?.lua')
table.insert(runtime_path, 'lua/?/init.lua')

-- Lua LSP config
lspconfig.sumneko_lua.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
        -- Setup your lua path
        path = runtime_path,
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file('', true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

-- Go LSP config
lspconfig.gopls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {"gopls", "serve"},
  settings = {
    gopls = {
      completeUnimported = true,
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
}

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
      luasnip.lsp_expand(args.body)
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
    { name = 'luasnip' },
    { name = 'path' },
    { name = 'buffer' },
  },
}

-- Use buffer source for `/`
cmp.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':'
cmp.setup.cmdline(':', {
  sources = {
    { name = 'path' },
    { name = 'cmdline' },
  }
})

-- mappings

-- Whichkey
mapx.nmap('<leader>w', ':WhichKey<CR>', 'silent', 'Open WhichKey')

mapx.nnoremap('<leader>ev', ':e $MYVIMRC<CR>', 'Edit neovim init.lua')
mapx.nnoremap('<leader>sv', ':source $MYVIMRC<CR>', 'Reload neovim init.lua')

-- Get rid of annoying mistakes
mapx.cmap('WQ', 'wq')
mapx.cmap('wQ', 'wq')
mapx.nnoremap(';', ':')
mapx.vnoremap(';', ':')
mapx.nnoremap(';;', ';')
mapx.vnoremap(';;', ';')
mapx.nnoremap(',,', ',')
mapx.vnoremap(',,', ',')
mapx.nnoremap(';', ':')

-- window movement
mapx.nmap('<A-h>', '<c-w>h')
mapx.nmap('<A-j>', '<c-w>j')
mapx.nmap('<A-k>', '<c-w>k')
mapx.nmap('<A-l>', '<c-w>l')

-- this maps leader + esc to exit terminal mode
mapx.tnoremap('<leader><Esc>', '<C-\\><C-n>')
-- This makes navigating windows the same no matter if they are displaying
-- a normal buffer or a terminal buffer
-- Move around windows in terminal
mapx.tnoremap('<A-h>', '<C-\\><C-n><C-w>h')
mapx.tnoremap('<A-j>', '<C-\\><C-n><C-w>j')
mapx.tnoremap('<A-k>', '<C-\\><C-n><C-w>k')
mapx.tnoremap('<A-l>', '<C-\\><C-n><C-w>l')

-- Wrapped lines goes down/up to next row, rather than next line in file.
mapx.nnoremap('j', 'gj')
mapx.nnoremap('k', 'gk')

-- Make Y behave like other capitals
-- Reselect visual block after indent
mapx.nnoremap('Y', 'y$')

mapx.vnoremap('<', '<gv')
mapx.vnoremap('>', '>gv')

-- Escape insert by hitting jj
mapx.inoremap('jj', '<ESC>')
-- Clear the current search highlights
mapx.nmap('<leader>/', ':nohlsearch<CR>', 'silent')
-- clear hlsearch on redraw
mapx.nnoremap('<C-L>', ':nohlsearch<CR><C-L>')

-- easy align
mapx.xmap('ga', '<Plug>(EasyAlign)')
mapx.nmap('ga', '<Plug>(EasyAlign)')

-- vim commentary
mapx.nmap('<M-/>', ':Commentary<CR>', 'silent')
mapx.vmap('<M-/>', ':Commentary<CR>')

-- nerdtree
mapx.map('<C-e>', ':NERDTreeToggle<CR>:NERDTreeMirror<CR>')

-- tagbar (requires remapped key in terminal emulator for "ctrl-shift-e" to work)
mapx.map('<m-e>', ':TagbarToggle<CR>')

-- vim-go
mapx.nmap('<leader>gb', ':GoBuild<cr>', 'silent')
vim.g.go_gopls_enabled = false

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

require('telescope').load_extension('fzf')

mapx.nnoremap('<c-p>', "<cmd>lua require('telescope.builtin').find_files()<cr>")
mapx.nnoremap('<m-o>', "<cmd>lua require('telescope.builtin').buffers()<cr>")
mapx.nnoremap('<m-p>', "<cmd>lua require('telescope.builtin').tags()<cr>")
mapx.nnoremap('<leader>ff', "<cmd>lua require('telescope.builtin').find_files()<cr>")
mapx.nnoremap('<leader>fg', "<cmd>lua require('telescope.builtin').live_grep()<cr>")
mapx.nnoremap('<leader>fb', "<cmd>lua require('telescope.builtin').buffers()<cr>")
mapx.nnoremap('<leader>fh', "<cmd>lua require('telescope.builtin').help_tags()<cr>")

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

-- Highlight on yank
vim.cmd [[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
  augroup end
]]

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
