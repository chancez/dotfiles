-- Automatically install packer
local install_path = vim.fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = vim.fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

packer.startup(function(use)
  -- package management
  use 'wbthomason/packer.nvim'

  -- performance
  use 'lewis6991/impatient.nvim'

  -- visual
  use 'navarasu/onedark.nvim'
  use 'norcalli/nvim-colorizer.lua'
  use 'preservim/tagbar'
  use {
    'kyazdani42/nvim-tree.lua',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true },
  }
  use {
    'nvim-lualine/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}
  }
  use {
    'lewis6991/gitsigns.nvim',
    requires = {
      'nvim-lua/plenary.nvim'
    },
  }
  use "lukas-reineke/indent-blankline.nvim"

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
  use 'simrat39/symbols-outline.nvim'
  use 'williamboman/nvim-lsp-installer'

  -- autocomplete
  use {
    'hrsh7th/nvim-cmp', -- Autocompletion plugin
    requires = {
      'hrsh7th/cmp-cmdline', -- cmdline source
      'hrsh7th/cmp-nvim-lsp', -- LSP source
      'hrsh7th/cmp-path', -- path source
      'hrsh7th/cmp-buffer', -- buffer source
    },
  }

  -- snippets
  use {
    'saadparwaiz1/cmp_luasnip', -- Snippets source for nvim-cmp
    after = "nvim-cmp",
  }
  use {
    'L3MON4D3/LuaSnip',
    config = function()
      require("luasnip/loaders/from_vscode").lazy_load()
    end,
    requires = {
      -- Snippet collections
      "rafamadriz/friendly-snippets",
    },
  }

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
  use 'windwp/nvim-autopairs'
  use { 'windwp/nvim-ts-autotag', requires = { 'nvim-treesitter/nvim-treesitter' }}
  use 'akinsho/toggleterm.nvim'
  use 'szw/vim-maximizer'

  -- multicursor support like sublime text
  use 'mg979/vim-visual-multi'

  -- git
  use 'tpope/vim-fugitive'
  --
  -- language/syntax integrations
  use 'jjo/vim-cue'
  use 'google/vim-jsonnet'
  use 'chr4/nginx.vim'
  use 'hashivim/vim-terraform'
  use 'fladson/vim-kitty'
  use 'towolf/vim-helm'

  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)

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
vim.opt.signcolumn = 'yes'
-- Look for tags in the project directory
vim.opt.tags = 'tags;'

-- indent-blankline
vim.opt.list = true
vim.opt.listchars:append("space:⋅")

require("indent_blankline").setup {
  space_char_blankline = " ",
  show_current_context = true,
  show_current_context_start = false,
}

-- clipboard
if vim.fn.has('unnamedplus') then vim.o.clipboard = 'unnamedplus' else vim.o.clipboard = 'unnamed' end

-- leader
vim.g.mapleader = ','

vim.g.python_host_prog = '~/.asdf/shims/python2'
vim.g.python3_host_prog = '~/.asdf/shims/python3'
vim.g.node_host_prog = '~/.asdf/shims/node'

-- language server

-- nvim-cmp supports additional completion capabilities
local cmp_lsp = require('cmp_nvim_lsp')

-- Diagnostic keymaps
mapx.group("silent", function()
  mapx.nnoremap('<leader>d', '<cmd>lua vim.diagnostic.open_float()<CR>', 'LSP Diagnostics')
  mapx.nnoremap('[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', 'Diagnostics goto previous')
  mapx.nnoremap(']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', 'Diagnostics goto next')
  mapx.nnoremap('<leader>q', '<cmd>lua vim.diagnostic.setloclist()<CR>', 'Diagnostics loclist')
end)

function OrgImports(wait_ms)
  local params = vim.lsp.util.make_range_params()
  params.context = {only = {"source.organizeImports"}}
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit)
      else
        vim.lsp.buf.execute_command(r.command)
      end
    end
  end
end

-- LSP settings
local default_on_attach = function(client, bufnr)
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  mapx.group({ buffer = bufnr }, function()
    mapx.cmdbang('LspRename', 'lua vim.lsp.buf.rename()')
    mapx.cmdbang('LspDeclaration', 'lua vim.lsp.buf.declaration()')
    mapx.cmdbang('LspDefinition', 'lua vim.lsp.buf.definition()')
    mapx.cmdbang('LspTypeDefinition', 'lua vim.lsp.buf.type_definition()')
    mapx.cmdbang('LspReferences', 'lua vim.lsp.buf.references()')
    mapx.cmdbang('LspImplementation', 'lua vim.lsp.buf.implementation()')

    mapx.cmdbang('LspCodeAction', 'lua vim.lsp.buf.code_action()')
    mapx.cmdbang('LspHover', 'lua vim.lsp.buf.hover()')
    mapx.cmdbang('LspSignatureHelp', 'lua vim.lsp.buf.signature_help()')

    mapx.cmdbang('LspAddWorkspaceFolder', 'lua vim.lsp.buf.add_workspace_folder()')
    mapx.cmdbang('LspRemoveWorkspaceFolder', 'lua vim.lsp.buf.remove_workspace_folder()')
    mapx.cmdbang('LspListWorkspaceFolders', 'lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))')

    mapx.cmdbang('LspDocumentSymbols', 'lua require("telescope.builtin").lsp_document_symbols()')
    mapx.cmdbang('LspWorkspaceSymbols', 'lua require("telescope.builtin").lsp_dynamic_workspace_symbols()')

    -- formatting
    if client.resolved_capabilities.document_formatting then
      mapx.cmdbang('LspFormat', 'lua vim.lsp.buf.formatting()')
      mapx.cmdbang('LspOrgImports', 'lua OrgImports(3000)')
      vim.api.nvim_command [[augroup Format]]
      vim.api.nvim_command [[autocmd! * <buffer>]]
      vim.api.nvim_command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
      vim.api.nvim_command [[autocmd BufWritePre *.go lua OrgImports(1000)]]
      vim.api.nvim_command [[augroup END]]
    end

    mapx.group("silent", function()
      mapx.nnoremap('<leader>rn', '<cmd>LspRename<CR>', 'LspRename')
      mapx.nnoremap('gD', '<cmd>LspDeclaration<CR>', 'LspDeclaration')
      mapx.nnoremap('gd', '<cmd>LspDefinition<CR>', 'LspDefinition')
      mapx.nnoremap('<leader>D', '<cmd>LspTypeDefinition<CR>', 'LspTypeDefinition')
      mapx.nnoremap('gr', '<cmd>LspReferences<CR>', 'LspReferences')
      mapx.nnoremap('gi', '<cmd>LspImplementation<CR>', 'LspImplementation')

      mapx.nnoremap('<leader>ca', '<cmd>LspCodeAction<CR>', 'LspCodeAction')
      mapx.nnoremap('K', '<cmd>LspHover<CR>', 'LspHover')
      mapx.nnoremap('<C-k>', '<cmd>LspSignatureHelp<CR>', 'LspSignatureHelp')

      mapx.nnoremap('<leader>wa', '<cmd>LspAddWorkspaceFolder<CR>', 'LspAddWorkspaceFolder')
      mapx.nnoremap('<leader>wr', '<cmd>LspRemoveWorkspaceFolder<CR>', 'LspRemoveWorkspaceFolder')
      mapx.nnoremap('<leader>wl', '<cmd>LspListWorkspaceFolders<CR>', 'LspListWorkspaceFolders')

      mapx.nnoremap('<leader>so', '<cmd>LspDocumentSymbols<CR>', 'LspDocumentSymbols')
      mapx.nnoremap('<leader>sp', '<cmd>LspWorkspaceSymbols<CR>', 'LspWorkspaceSymbols')
      mapx.nnoremap('<m-p>', '<cmd>LspWorkspaceSymbols<CR>', 'LspWorkspaceSymbols')
    end)
  end)
end

local lsp_installer_servers = require('nvim-lsp-installer.servers')

-- Insert runtime_path of neovim lua files for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, 'lua/?.lua')
table.insert(runtime_path, 'lua/?/init.lua')

local servers = {
  clangd = {},
  rust_analyzer = {},
  pyright = {},
  tsserver  = {},
  bashls  = {},
  dockerls  = {},
  jsonnet_ls = {},
  sqls = {},
  terraformls = {},
  esbonio = {}, -- Sphinx/RestructuredText
  jdtls  = {},
  sumneko_lua = {
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
  },
  gopls = {
    cmd = {"gopls", "serve"},
    settings = {
      gopls = {
        env = {
          GOFLAGS="-tags=e2e_tests,linux,go1.17",
        },
        completeUnimported = true,
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
        -- gofumpt = true,
      },
    },
  },
  yamlls = {
    settings = {
      yaml = {
        schemaStore = {
          url = "https://www.schemastore.org/api/json/catalog.json",
          enable = true,
        }
      }
    },
    on_attach = function(client, bufnr)
      default_on_attach(client, bufnr)

      if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
        local namespace = vim.lsp.diagnostic.get_namespace(client.id)
        vim.diagnostic.disable(bufnr, namespace)
      end
    end,
  },
}

-- Loop through the servers listed above and set them up. If a server is
-- not already installed, install it.
for server_name, server_specific_opts in pairs(servers) do
  local capabilities = cmp_lsp.update_capabilities(vim.lsp.protocol.make_client_capabilities())
  local server_opts = {
    on_attach = default_on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    },
  }

  for k,v in pairs(server_specific_opts) do
    server_opts[k] = v
  end


  local server_available, server = lsp_installer_servers.get_server(server_name)
  if server_available then
      if not server:is_installed() then
        print("Installing " .. server_name)
        -- Queue the server to be installed.
        server:install()
      end
      server:on_ready(function ()
        server:setup(server_opts)
      end)
  end
end

-- lsp signature
require('lsp_signature').setup {
  zindex = 50,
  bind = true, -- This is mandatory, otherwise border config won't get registered.
  handler_opts = {
    border = "rounded"
  },
  toggle_key = "<M-x>",
  floating_window_off_x = 60,
}

-- luasnip setup
local luasnip = require 'luasnip'
luasnip.config.set_config {
    history = true,
    updateevents = "TextChanged,TextChangedI"
}

-- nvim-cmp setup
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
local cmp = require 'cmp'
cmp.event:on( 'confirm_done', cmp_autopairs.on_confirm_done({  map_char = { tex = '' } }))

---@diagnostic disable-next-line: redundant-parameter
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
mapx.nnoremap('<leader>ps', ':source $MYVIMRC<CR>:PackerSync<CR>', 'Reload init.lua and run PackerSync')
mapx.nnoremap('<leader>pc', ':source $MYVIMRC<CR>:PackerCompile<CR>', 'Reload init.lua and run PackerCompile')

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

-- Buffer movement
mapx.nmap('<m-]>', ':bnext<CR>', 'Next buffer')
mapx.nmap('<m-[>', ':bprev<CR>', 'Previous buffer')

-- Wrapped lines goes down/up to next row, rather than next line in file.
mapx.nnoremap('j', 'gj')
mapx.nnoremap('k', 'gk')

-- Make Y behave like other capitals
mapx.nnoremap('Y', 'y$')

-- Reselect visual block after indent
mapx.vnoremap('<', '<gv')
mapx.vnoremap('>', '>gv')

-- Escape insert by hitting jj
mapx.inoremap('jj', '<ESC>')
-- Clear the current search highlights
mapx.nmap('<leader>/', ':nohlsearch<CR>', 'silent', 'Clear search hightlights')
-- clear hlsearch on redraw
mapx.nnoremap('<C-L>', ':nohlsearch<CR><C-L>', 'Clear search hightlights')

-- easy align
mapx.xmap('ga', '<Plug>(EasyAlign)', 'Easy align')
mapx.nmap('ga', '<Plug>(EasyAlign)', 'Easy align')

-- vim commentary
mapx.nmap('<M-/>', ':Commentary<CR>', 'silent')
mapx.vmap('<M-/>', ':Commentary<CR>', 'silent')

-- nvim-tree
mapx.map('<C-e>', ':NvimTreeToggle<CR>', 'silent')

-- tagbar
mapx.map('<m-e>', ':TagbarToggle<CR>', 'silent')

-- symbols outline
mapx.map('<m-r>', ':SymbolsOutline<CR>', 'silent')

-- vim-maximizer
vim.g.maximizer_default_mapping_key = '<c-w>0'

-- colorscheme
require('onedark').setup {
  style = 'dark'
}
require('onedark').load()

-- lualine
require'lualine'.setup {
  options = {theme = 'onedark'},
  extensions = {'toggleterm'},
  sections = {
    lualine_c = {
      {
        'filename',
        path = 1,
      }
    },
  },
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

-- nvim-tree
require 'nvim-tree'.setup()

-- symbols-outline
vim.g.symbols_outline = {
  width = 40,
}

-- toggleterm
require("toggleterm").setup {
  open_mapping = '<c-t>',
}

-- gitsigns
require('gitsigns').setup()

-- setup colorizer
require('colorizer').setup()

-- telescope
local actions = require("telescope.actions")

require('telescope').setup {
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    }
  },
 defaults = require('telescope.themes').get_ivy {
    layout_config = {
      scroll_speed = 5,
    },
    mappings = {
      i = {
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<M-k>"] = actions.preview_scrolling_up,
        ["<M-j>"] = actions.preview_scrolling_down,
        ["<C-u>"] = false,
        ["<C-d>"] = false,
        ["<esc>"] = actions.close,

      },
      n = {
        ["<C-k>"] = "move_selection_previous",
        ["<C-j>"] = "move_selection_next",
      },
    }
  },
  pickers = {
    find_files = {
      find_command = { 'rg', '--files', '--hidden', '--no-binary' },
    },
    buffers = {
      ignore_current_buffer = true,
      sort_mru = true,
    },
  },
}

require('telescope').load_extension('fzf')

mapx.nnoremap('<c-p>', "<cmd>lua require('telescope.builtin').find_files()<cr>", 'Telescope find_files')
mapx.nnoremap('<m-o>', "<cmd>lua require('telescope.builtin').buffers()<cr>", 'Telescope buffers')
-- mapx.nnoremap('<m-p>', "<cmd>lua require('telescope.builtin').tags()<cr>", 'Telescope tags')
mapx.nnoremap('<c-_>', "<cmd>lua require('telescope.builtin').current_buffer_fuzzy_find()<cr>", 'Telescope current_buffer_fuzzy_find') -- ctrl-/
mapx.nnoremap('<c-g>', "<cmd>lua require('telescope.builtin').grep_string()<cr>", 'Telescope grep_string')
mapx.nnoremap('<m-;>', "<cmd>lua require('telescope.builtin').command_history()<cr>", 'Telescope command_history')

mapx.nnoremap('<leader>ff', "<cmd>lua require('telescope.builtin').find_files()<cr>", 'Telescope find_files')
mapx.nnoremap('<leader>fg', "<cmd>lua require('telescope.builtin').live_grep()<cr>", 'Telescope live_grep')
mapx.nnoremap('<leader>fb', "<cmd>lua require('telescope.builtin').buffers()<cr>", 'Telescope buffers')
mapx.nnoremap('<leader>fh', "<cmd>lua require('telescope.builtin').help_tags()<cr>", 'Telescope help_tags')

-- setup treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained",
  highlight = { enable = true },
}

-- Autopairs
require('nvim-autopairs').setup{
  check_ts = true,
}

-- Autotag
require('nvim-ts-autotag').setup()

-- vim-visual-multi
vim.g.VM_custom_remaps = {
  ['<c-p>'] = 'Q', -- map c-p to previous
  ['<c-x>'] = 'q', -- map c-x to skip
}

-- show trailing whitespace https://vim.fandom.com/wiki/Highlight_unwanted_spaces
vim.cmd([[
  autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
  match ExtraWhitespace /\s\+$/
  autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
  autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
  autocmd InsertLeave * match ExtraWhitespace /\s\+$/
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

-- JQ formats JSON in the current buffer
vim.cmd [[
  function! JQFun(...)
    execute '%!jq .'
  endfunction
  command! -nargs=* -complete=file JQ call JQFun( '<f-args>' )
]]
