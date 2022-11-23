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
  use { 'nvim-treesitter/nvim-treesitter-context', requires = { 'nvim-treesitter/nvim-treesitter' }}
  use 'chentoast/marks.nvim'

  -- search
  use {
    'nvim-telescope/telescope.nvim',
    requires = {
      'nvim-lua/popup.nvim',
      'nvim-telescope/telescope-frecency.nvim',
      'nvim-lua/plenary.nvim',
      {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' },
      "nvim-telescope/telescope-file-browser.nvim",
      { "nvim-telescope/telescope-dap.nvim", requires = { 'mfussenegger/nvim-dap' }},
      'nvim-telescope/telescope-symbols.nvim',
    },
  }

  -- treesitter
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
  use 'j-hui/fidget.nvim'
  use { 'williamboman/mason.nvim' }
  use { 'williamboman/mason-lspconfig.nvim' , requires = { 'williamboman/mason.nvim' }}

  -- debug adapter protocol
  use 'mfussenegger/nvim-dap'
  use { 'leoluz/nvim-dap-go', requires = { 'mfussenegger/nvim-dap' } }
  use { 'rcarriga/nvim-dap-ui', requires = {'mfussenegger/nvim-dap'} }

  -- autocomplete
  use {
    'hrsh7th/nvim-cmp', -- Autocompletion plugin
    requires = {
      'hrsh7th/cmp-cmdline', -- cmdline source
      'hrsh7th/cmp-nvim-lsp', -- LSP source
      'hrsh7th/cmp-path', -- path source
      'hrsh7th/cmp-buffer', -- buffer source
      {'tzachar/cmp-fuzzy-path', requires = {'tzachar/fuzzy.nvim'}} -- fuzzy path source
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
  use {
    "nvim-neotest/neotest",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-neotest/neotest-go",
    }
  }

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
vim.opt.foldnestmax = 10 -- 10 nested fold max
mapx.nnoremap('<space>', 'za', 'Toggle folds')
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"

-- indent-blankline
vim.opt.list = true
vim.opt.listchars:append("space:⋅")

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

function OrgImports(wait_ms)
  local params = vim.lsp.util.make_range_params()
  params.context = {only = {"source.organizeImports"}}
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit, "utf-16")
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
    mapx.cmdbang('LspDefinition', 'lua require("telescope.builtin").lsp_definitions()')
    mapx.cmdbang('LspTypeDefinition', 'lua require("telescope.builtin").lsp_type_definitions()')
    mapx.cmdbang('LspReferences', 'lua require("telescope.builtin").lsp_references()')
    mapx.cmdbang('LspImplementation', 'lua require("telescope.builtin").lsp_implementations()')

    mapx.cmdbang('LspCodeAction', 'lua vim.lsp.buf.code_action()')
    mapx.cmdbang('LspHover', 'lua vim.lsp.buf.hover()')
    mapx.cmdbang('LspSignatureHelp', 'lua vim.lsp.buf.signature_help()')

    mapx.cmdbang('LspAddWorkspaceFolder', 'lua vim.lsp.buf.add_workspace_folder()')
    mapx.cmdbang('LspRemoveWorkspaceFolder', 'lua vim.lsp.buf.remove_workspace_folder()')
    mapx.cmdbang('LspListWorkspaceFolders', 'lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))')

    mapx.cmdbang('LspDocumentSymbols', 'lua require("telescope.builtin").lsp_document_symbols()')
    mapx.cmdbang('LspWorkspaceSymbols', 'lua require("telescope.builtin").lsp_dynamic_workspace_symbols()')
    mapx.cmdbang('LspIncomingCalls', 'lua require("telescope.builtin").lsp_incoming_calls()')
    mapx.cmdbang('LspOutgoingCalls', 'lua require("telescope.builtin").lsp_outgoing_calls()')

    -- formatting
    if client.server_capabilities.documentFormattingProvider then
      mapx.cmdbang('LspFormat', 'lua vim.lsp.buf.formatting()')
      mapx.cmdbang('LspOrgImports', 'lua OrgImports(3000)')
      vim.api.nvim_command [[augroup Format]]
      vim.api.nvim_command [[autocmd! * <buffer>]]
      vim.api.nvim_command [[autocmd BufWritePre *.go lua OrgImports(1000)]]
      vim.api.nvim_command [[autocmd BufWritePre *.go lua vim.lsp.buf.formatting_seq_sync(nil, 2000)]]
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
      mapx.nnoremap('<m-O>', '<cmd>LspDocumentSymbols<CR>', 'LspDocumentSymbols')
      mapx.nnoremap('<m-p>', '<cmd>LspWorkspaceSymbols<CR>', 'LspWorkspaceSymbols')
    end)
  end)
end

-- Diagnostic keymaps
mapx.cmdbang('Diagnostics', 'lua require("telescope.builtin").diagnostics()')
mapx.group("silent", function()
  mapx.nnoremap('<leader>d', '<cmd>Diagnostics<CR>', 'Diagnostics')
  mapx.nnoremap('[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', 'Diagnostics goto previous')
  mapx.nnoremap(']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', 'Diagnostics goto next')
  mapx.nnoremap('<leader>q', '<cmd>lua vim.diagnostic.setloclist()<CR>', 'Diagnostics loclist')
end)


-- Insert runtime_path of neovim lua files for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, 'lua/?.lua')
table.insert(runtime_path, 'lua/?/init.lua')

-- see if the file exists
function FileExists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- Get the value of the module name from go.mod in PWD
function GetGoModuleName()
  if not FileExists("go.mod") then return nil end
  for line in io.lines("go.mod") do
    if vim.startswith(line, "module") then
      local items = vim.split(line, " ")
      local module_name = vim.trim(items[2])
      return module_name
    end
  end
  return nil
end

GO_MODULE = GetGoModuleName()

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
          GOFLAGS="-tags=e2e_tests,integration,linux,go1.17,e2e",
        },
        completeUnimported = true,
        analyses = {
          nilness = true,
          unusedparams = true,
          unusedwrite = true,
          shadow = true,
        },
        staticcheck = true,
        usePlaceholders = true,
        experimentalUseInvalidMetadata = true,
        -- ["local"] = GO_MODULE,
        -- gofumpt = true,
      },
    },
  },
  golangci_lint_ls = {},
  yamlls = {
    settings = {
      yaml = {
        schemas = {
          ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
          -- kubernetes = "/install/kubernetes/**.yaml",
        },
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
  tilt_ls = {},
}


require("mason").setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗"
    }
  }
})

require("mason-lspconfig").setup({
  -- ensure_installed = get_keys(servers),
  automatic_installation = true,
})

for server_name, server_specific_opts in pairs(servers) do
  local capabilities = cmp_lsp.default_capabilities()
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

  require("lspconfig")[server_name].setup(server_opts)
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

-- show LSP loading status
require"fidget".setup{}

-- debug adapter
require('dap-go').setup()
require("dapui").setup()

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
    ['<Up>'] = cmp.mapping.select_prev_item(),
    ['<Down>'] = cmp.mapping.select_next_item(),
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
    { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '20', '-p', '--no-ignore'}} },
    { name = 'buffer' },
  },
}

-- Use buffer source for `/`
cmp.setup.cmdline('/', {
  mapping = {
    ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
    ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
    ['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
    ['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), {'i', 'c'}),
    ['<C-e>'] = cmp.mapping(cmp.mapping.close(), {'i', 'c'}),
  },
  sources = {
    { name = 'buffer' },
  }
})

-- Use cmdline & path source for ':'
cmp.setup.cmdline(':', {
  mapping = {
    ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
    ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
    ['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
    ['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), {'i', 'c'}),
    ['<C-e>'] = cmp.mapping(cmp.mapping.close(), {'i', 'c'}),
  },
  sources = {
    { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '20', '-p', '--no-ignore'}} },
    { name = 'cmdline' },
  }
})
-- https://github.com/nvim-neotest/neotest-go#installation
-- The vim.diagnostic.config is optional but recommended if you
-- enabled the diagnostic option of neotest. Especially testify makes heavy use
-- of tabs and newlines in the error messages, which reduces the readability of
-- the generated virtual text otherwise.
--
-- get neotest namespace (api call creates or returns namespace)
local neotest_ns = vim.api.nvim_create_namespace("neotest")
vim.diagnostic.config({
  virtual_text = {
    format = function(diagnostic)
      local message = diagnostic.message
      :gsub("\n", " ")
      :gsub("\t", " ")
      :gsub("%s+", " ")
      :gsub("^%s+", "")
      return message
    end,
  },
}, neotest_ns)

require('neotest').setup({
  adapters = {
    require('neotest-go'),
  },
  icons = {
    passed = "",
    running = "",
    skipped = "",
    unknown = "",
  },
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

-- Indenting Move to next/previous line with same indentation
mapx.nnoremap('<M-,>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%<' . line('.') . 'l\S', 'be')<CR>]], 'Move to next line with same indentation')
mapx.nnoremap('<M-.>', [[:call search('^'. matchstr(getline('.'), '\(^\s*\)') .'\%>' . line('.') . 'l\S', 'e')<CR>]], 'Move to previous line with same indentation')

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

-- nvim-dap
mapx.cmdbang('DapStepBack', 'lua require("dap").step_back()')
mapx.cmdbang('DapStepInto', 'lua require("dap").step_into()')
mapx.cmdbang('DapStepOver', 'lua require("dap").step_over()')
mapx.cmdbang('DapStepOut', 'lua require("dap").step_out()')
mapx.cmdbang('DapContinue', 'lua require("dap").continue()')
mapx.cmdbang('DapToggleBreakpoint', 'lua require("dap").toggle_breakpoint()')
mapx.cmdbang('DapListBreakpoints', 'lua require("dap").list_breakpoints()')
mapx.cmdbang('DapClearBreakpoints', 'lua require("dap").clear_breakpoints()')
mapx.cmdbang('DapREPLOpen', 'lua require("dap").repl.open()')
mapx.cmdbang('DapREPLClose', 'lua require("dap").repl.close()')
mapx.cmdbang('DapREPLToggle', 'lua require("dap").repl.toggle()')
-- dap-go
mapx.cmdbang('DapGoTest', 'lua require("dap-go").debug_test()')
mapx.cmdbang('DapUIOpen', 'lua require("dapui").open()')
-- dap-ui
mapx.cmdbang('DapUIClose', 'lua require("dapui").close()')
mapx.cmdbang('DapUIToggle', 'lua require("dapui").toggle()')

-- neotest
mapx.cmdbang('TestNearest', 'lua require("neotest").run.run()')
mapx.cmdbang('TestFile', 'lua require("neotest").run.run(vim.fn.expand("%"))')
mapx.cmdbang('TestDirectory', 'lua require("neotest").run.run(vim.fn.expand("%:p:h"))')
mapx.cmdbang('TestSuite', 'lua require("neotest").run.run(vim.fn.getcwd())')
mapx.cmdbang('TestOpen', 'lua require("neotest").output.open()')
mapx.map('gtn', ':TestNearest<CR>', 'silent')
mapx.map('gtf', ':TestFile<CR>', 'silent')
mapx.map('gtd', ':TestDirectory<CR>', 'silent')
mapx.map('gts', ':TestSuite<CR>', 'silent')
mapx.map('gto', ':TestOpen<CR>', 'silent')

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
        mode = 4,
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

require("indent_blankline").setup {
  space_char_blankline = " ",
  show_current_context = true,
  show_current_context_start = false,
}

require('marks').setup {
  default_mappings = false,
}

-- symbols-outline
vim.g.symbols_outline = {
  width = 40,
}

-- toggleterm
local toggleterm = require("toggleterm")
toggleterm.setup {
  open_mapping = '<c-t>',
}

local toggletermutils = require("toggleterm.utils")
--- @param selection_type string
--- @param trim_spaces boolean
--- @param cmd_data table<string, any>
function ToggleTerm_send_lines_to_terminal(selection_type, trim_spaces, cmd_data)
  local id = tonumber(cmd_data.args) or 1
  trim_spaces = trim_spaces == nil or trim_spaces

  vim.validate({
    selection_type = { selection_type, "string", true },
    trim_spaces = { trim_spaces, "boolean", true },
    terminal_id = { id, "number", true },
  })

  local current_window = vim.api.nvim_get_current_win() -- save current window

  local lines = {}
  -- Beginning of the selection: line number, column number
  local start_line, start_col
  if selection_type == "single_line" then
    start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    table.insert(lines, vim.fn.getline(start_line))
  elseif selection_type == "visual_lines" then
    local res = toggletermutils.get_line_selection("visual")
    start_line, start_col = unpack(res.start_pos)
    lines = res.selected_lines
  elseif selection_type == "visual_selection" then
    local res = toggletermutils.get_line_selection("visual")
    start_line, start_col = unpack(res.start_pos)
    lines = toggletermutils.get_visual_selection(res)
  elseif selection_type == "current_buffer" then
    start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  if not lines or not next(lines) then return end

  for _, line in ipairs(lines) do
    local l = trim_spaces and line:gsub("^%s+", ""):gsub("%s+$", "") or line
    toggleterm.exec(l, id)
  end

  -- Jump back with the cursor where we were at the beginning of the selection
  vim.api.nvim_set_current_win(current_window)
  vim.api.nvim_win_set_cursor(current_window, { start_line, start_col })
end

mapx.cmdbang('ToggleTermSendCurrentBuffer', function(args) ToggleTerm_send_lines_to_terminal("current_buffer", false, args) end)

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
    },
    file_browser = {
      theme = "ivy",
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
    },
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
        -- we want ctrl-u to be clear the prompt, so disable the default binding
        ["<C-u>"] = false,
        -- disable c-d because we don't have c-u mapped
        ["<C-d>"] = false,
        ["<esc>"] = actions.close,
        ["<C-h>"] = "which_key",
        ["<C-s>"] = actions.cycle_previewers_next,
        ["<C-a>"] = actions.cycle_previewers_prev,

      },
      n = {
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
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
require("telescope").load_extension('file_browser')
require('telescope').load_extension('dap')

mapx.nnoremap('<c-p>', "<cmd>lua require('telescope.builtin').find_files()<cr>", 'Telescope find_files')
mapx.nnoremap('<m-o>', "<cmd>lua require('telescope.builtin').buffers()<cr>", 'Telescope buffers')
mapx.nnoremap('<c-b>', "<cmd>lua require('telescope.builtin').current_buffer_fuzzy_find()<cr>", 'Telescope current_buffer_fuzzy_find')
mapx.nnoremap('<c-g>', "<cmd>lua require('telescope.builtin').grep_string()<cr>", 'Telescope grep_string')
mapx.nnoremap('<m-;>', "<cmd>lua require('telescope.builtin').command_history()<cr>", 'Telescope command_history')

mapx.nnoremap('<leader>ff', "<cmd>lua require('telescope.builtin').find_files()<cr>", 'Telescope find_files')
mapx.nnoremap('<leader>fg', "<cmd>lua require('telescope.builtin').live_grep()<cr>", 'Telescope live_grep')
mapx.nnoremap('<leader>fB', "<cmd>lua require('telescope.builtin').buffers()<cr>", 'Telescope buffers')
mapx.nnoremap('<leader>fh', "<cmd>lua require('telescope.builtin').help_tags()<cr>", 'Telescope help_tags')
mapx.nnoremap('<leader>fr', "<cmd>lua require('telescope.builtin').registers()<cr>", 'Telescope registers')
mapx.nnoremap('<leader>fm', "<cmd>lua require('telescope.builtin').marks()<cr>", 'Telescope marks')

mapx.nnoremap('<leader>fb', "<cmd>lua require('telescope').extensions.file_browser.file_browser()<cr>", 'Telescope file_browser')

-- setup treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = {
    "c", "lua", "go", "rust", "python", "javascript", "typescript", "comment",
    "dockerfile", "gomod", "gowork", "hcl", "html", "java", "json", "latex",
    "markdown", "make", "proto", "regex", "toml", "vim", "yaml",
  },
  highlight = { enable = true },
}

require("treesitter-context").setup({
	enable = true,
	patterns = {
		json = {
			"object",
			"pair",
		},
		yaml = {
			"block_mapping_pair",
			"block_sequence_item",
		},
		toml = {
			"table",
			"pair",
		},
		markdown = {
			"section",
		},
	},
})

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
vim.g.VM_maps = {
  ["I BS"] = '', -- disable backspace mapping
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

vim.cmd [[autocmd! BufNewFile,BufRead Tiltfile set filetype=tiltfile syntax=python]]

-- Highlight on yank
vim.cmd [[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
  augroup end
]]

-- JQ formats JSON in the current buffer
vim.cmd [[
  " command! -nargs=* JQ execute '%!jq "<args>"'
  command! -nargs=* JQ execute '%!jq <args>'
]]
