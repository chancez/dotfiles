-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- performance
vim.loader.enable()

-- Setup lazy.nvim
require("lazy").setup({
  -- do not automatically check for plugin updates
  checker = { enabled = false },

  spec = {
    -- visual
    { 'navarasu/onedark.nvim' },
    { 'norcalli/nvim-colorizer.lua' },
    { 'kyazdani42/nvim-web-devicons' },

    { 'preservim/tagbar' },

    {
      'nvim-lualine/lualine.nvim',
      dependencies = { 'kyazdani42/nvim-web-devicons', lazy = true }
    },

    {
      'lewis6991/gitsigns.nvim',
      dependencies = {
        'nvim-lua/plenary.nvim'
      },
    },

    { 'lukas-reineke/indent-blankline.nvim' },
    { 'nvim-treesitter/nvim-treesitter-context', dependencies = { 'nvim-treesitter/nvim-treesitter' }},
    { 'chentoast/marks.nvim' },

    -- search
    {
      'nvim-telescope/telescope.nvim',
      dependencies = {
        'nvim-lua/popup.nvim',
        'nvim-telescope/telescope-frecency.nvim',
        'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
        "nvim-telescope/telescope-file-browser.nvim",
        { "nvim-telescope/telescope-dap.nvim", dependencies = { 'mfussenegger/nvim-dap' }},
        'nvim-telescope/telescope-symbols.nvim',
      },
    },

    -- treesitter
    {
      'nvim-treesitter/nvim-treesitter',
      dependencies = {
        'nvim-treesitter/nvim-treesitter-refactor',
        'nvim-treesitter/nvim-treesitter-textobjects',
      },
      build = ':TSUpdate',
    },

    -- LSP
    { 'neovim/nvim-lspconfig' },
    { 'ray-x/lsp_signature.nvim' },
    { 'onsails/lspkind-nvim' },
    { 'j-hui/fidget.nvim' },
    { 'williamboman/mason.nvim' },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim" },
            "neovim/nvim-lspconfig",
        },
    },

    -- debug adapter protocol
    { 'mfussenegger/nvim-dap' },
    { 'leoluz/nvim-dap-go', dependencies = { 'mfussenegger/nvim-dap' } },
    { 'rcarriga/nvim-dap-ui', dependencies = {'mfussenegger/nvim-dap', "nvim-neotest/nvim-nio" } },

    -- autocomplete
    {
      'hrsh7th/nvim-cmp', -- Autocompletion plugin
      dependencies = {
        'hrsh7th/cmp-cmdline', -- cmdline source
        'hrsh7th/cmp-nvim-lsp', -- LSP source
        'hrsh7th/cmp-path', -- path source
        'hrsh7th/cmp-buffer', -- buffer source
        { 'tzachar/cmp-fuzzy-path', dependencies = {'tzachar/fuzzy.nvim'} }, -- fuzzy path source
        { 'zbirenbaum/copilot-cmp', dependencies = {'zbirenbaum/copilot.lua'} },
        { 'saadparwaiz1/cmp_luasnip', dependencies = { 'L3MON4D3/LuaSnip' } }, -- Snippets source for nvim-cmp
      },
    },

    -- AI
    { 'zbirenbaum/copilot.lua' },
    {
      "olimorris/codecompanion.nvim",
      opts = {
        strategies = {
          chat = {
            adapter = "copilot",
          },
          inline = {
            adapter = "copilot",
          },
          cmd = {
            adapter = "copilot",
          },
        },
        extensions = {
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              make_vars = true,
              make_slash_commands = true,
              show_result_in_chat = true
            }
          }
        }
      },
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        {
          "ravitemer/mcphub.nvim",
        },
      },
    },

    {
      'L3MON4D3/LuaSnip',
      config = function()
        require("luasnip/loaders/from_vscode").lazy_load()
      end,
      dependencies = {
        -- Snippet collections
        "rafamadriz/friendly-snippets",
      },
    },

    -- utilities that leverage vim verbs
    { 'tpope/vim-repeat' },
    { 'tpope/vim-unimpaired' },
    { 'tpope/vim-surround' },

    -- utilities
    { 'tpope/vim-commentary' },
    { 'tpope/vim-eunuch' },
    { 'junegunn/vim-easy-align' },
    {
      'folke/which-key.nvim',
      dependencies = {'kyazdani42/nvim-web-devicons', opt = true}
    },
    { 'windwp/nvim-autopairs' },
    { 'windwp/nvim-ts-autotag', dependencies = { 'nvim-treesitter/nvim-treesitter' } },
    { 'akinsho/toggleterm.nvim' },
    { 'szw/vim-maximizer' },
    {
      "nvim-neotest/neotest",
      dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",
        "nvim-neotest/neotest-go",
      }
    },
    { 'nicwest/vim-camelsnek' },
    { 'stevearc/qf_helper.nvim' },
    { 'ojroques/nvim-osc52' },
    { 'lambdalisue/vim-suda' },

    {
      'rmagatti/auto-session',
      lazy = false,

      ---enables autocomplete for opts
      ---@module "auto-session"
      ---@type AutoSession.Config
      opts = {
        suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
      }
    },

    -- multicursor support like sublime text
    { 'mg979/vim-visual-multi' },

    -- git
    { 'tpope/vim-fugitive' },
    --
    -- language/syntax integrations
    { 'jjo/vim-cue' },
    { 'google/vim-jsonnet' },
    { 'chr4/nginx.vim' },
    { 'hashivim/vim-terraform' },
    { 'fladson/vim-kitty' },
    { 'vito-c/jq.vim' },
    { 'HiPhish/jinja.vim' },
    { 'towolf/vim-helm', ft = 'helm' },
  },
})


local wk = require("which-key")

-- misc global opts
vim.opt.spell = true
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
wk.add({{'<space>', 'za', desc = 'Toggle folds', mode='n'}})
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"

-- https://github.com/rmagatti/auto-session?tab=readme-ov-file#recommended-sessionoptions-config
vim.opt.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.cmd [[ packadd cfilter ]]

-- indent-blankline
vim.opt.list = true
vim.opt.listchars:append("space:⋅")

-- clipboard
if vim.fn.has('unnamedplus') then vim.o.clipboard = 'unnamedplus' else vim.o.clipboard = 'unnamed' end

local osc52 = require('osc52')
wk.add({
  {'<leader>c', function() osc52.copy_operator() end, desc = 'Copy to clipboard with OSC52'},
  {'<leader>c', function() osc52.copy_visual() end, desc = 'Copy to clipboard with OSC52', mode='v'},
})

-- leader
vim.g.mapleader = ','

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
  vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', { buf = bufnr })

  vim.api.nvim_buf_create_user_command(bufnr, 'LspRename', function() vim.lsp.buf.rename() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspDeclaration', function() vim.lsp.buf.declaration() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspDefinition', function() require("telescope.builtin").lsp_definitions({fname_width=75}) end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspTypeDefinition', function() require("telescope.builtin").lsp_type_definitions() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspReferences', function() require("telescope.builtin").lsp_references({fname_width=75}) end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspImplementation', function() require("telescope.builtin").lsp_implementations() end, { bang = true })

  vim.api.nvim_buf_create_user_command(bufnr, 'LspCodeAction', function() vim.lsp.buf.code_action() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspHover', function() vim.lsp.buf.hover() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspSignatureHelp', function() vim.lsp.buf.signature_help() end, { bang = true })

  vim.api.nvim_buf_create_user_command(bufnr, 'LspAddWorkspaceFolder', function() vim.lsp.buf.add_workspace_folder() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspRemoveWorkspaceFolder', function() vim.lsp.buf.remove_workspace_folder() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspListWorkspaceFolders', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, { bang = true })

  vim.api.nvim_buf_create_user_command(bufnr, 'LspDocumentSymbols', function() require("telescope.builtin").lsp_document_symbols() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspWorkspaceSymbols', function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspIncomingCalls', function() require("telescope.builtin").lsp_incoming_calls() end, { bang = true })
  vim.api.nvim_buf_create_user_command(bufnr, 'LspOutgoingCalls', function() require("telescope.builtin").lsp_outgoing_calls() end, { bang = true })

  -- formatting
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_buf_create_user_command(bufnr, 'LspFormat', function() vim.lsp.buf.format() end, { bang = true })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspOrgImports', function() OrgImports(3000) end, { bang = true })
    vim.api.nvim_create_augroup('CodeFormat', { clear = false })
    vim.api.nvim_create_autocmd({'BufWritePre'}, {
      -- buffer = bufnr,
      group = 'CodeFormat',
      pattern = {"*.go"},
      callback = function()
        OrgImports(1000)
        vim.lsp.buf.format({timeout_ms=2000})
      end
    })
  end

  wk.add({
    mode='n',
    silent = true,
    buffer = bufnr,
    {'<leader>rn', '<cmd>LspRename<CR>', desc = 'LspRename'},
    {'gD', '<cmd>LspDeclaration<CR>', desc = 'LspDeclaration'},
    {'gd', '<cmd>LspDefinition<CR>', desc = 'LspDefinition'},
    {'<leader>D', '<cmd>LspTypeDefinition<CR>', desc = 'LspTypeDefinition'},
    {'gr', '<cmd>LspReferences<CR>', desc = 'LspReferences'},
    {'gi', '<cmd>LspImplementation<CR>', desc = 'LspImplementation'},

    {'<leader>ca', '<cmd>LspCodeAction<CR>', desc = 'LspCodeAction'},
    {'K', '<cmd>LspHover<CR>', desc = 'LspHover'},
    {'<C-k>', '<cmd>LspSignatureHelp<CR>', desc = 'LspSignatureHelp'},

    {'<leader>wa', '<cmd>LspAddWorkspaceFolder<CR>', desc = 'LspAddWorkspaceFolder'},
    {'<leader>wr', '<cmd>LspRemoveWorkspaceFolder<CR>', desc = 'LspRemoveWorkspaceFolder'},
    {'<leader>wl', '<cmd>LspListWorkspaceFolders<CR>', desc = 'LspListWorkspaceFolders'},

    {'<leader>so', '<cmd>LspDocumentSymbols<CR>', desc = 'LspDocumentSymbols'},
    {'<leader>sp', '<cmd>LspWorkspaceSymbols<CR>', desc = 'LspWorkspaceSymbols'},
    {'<m-O>', '<cmd>LspDocumentSymbols<CR>', desc = 'LspDocumentSymbols'},
    {'<m-p>', '<cmd>LspWorkspaceSymbols<CR>', desc = 'LspWorkspaceSymbols'},
  })
end

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
  clangd = {
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- remove proto, handled by bufls
  },
  rust_analyzer = {},
  pyright = {},
  ts_ls  = {},
  bashls  = {},
  dockerls  = {},
  jsonnet_ls = {},
  sqlls = {},
  terraformls = {},
  esbonio = {}, -- Sphinx/RestructuredText
  jdtls  = {},
  lua_ls = {
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
          checkThirdParty = false,
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
        buildFlags = {
          "-tags=e2e_tests,integration,e2e,hubble_cli_e2e,enterprise_hubble_rbac_e2e,enterprise_integrated_timescape_e2e,helm",
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
        -- ["local"] = GO_MODULE,
        -- gofumpt = true,
      },
    },
  },
  yamlls = {
    filetypes = { 'yaml', 'yaml.docker-compose' },
    settings = {
      yaml = {
        validate = false,
        schemas = {
          ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
          -- kubernetes = "/install/kubernetes/**.yaml",
        },
      }
    },
  },
  helm_ls = {},
  buf_ls = {},
  kotlin_language_server = {},
  graphql = {
    filetypes = { "typescript", "typescriptreact", "graphql" },
    settings = {
      ["graphql-config.load.legacy"] = true,
    }
  },
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
  ensure_installed = vim.tbl_keys(servers),
  automatic_installation = true,
  automatic_enable = false,
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

-- copilot.lua
require("copilot").setup({
  -- disable suggestions and panel since we're using cmp
  suggestion = { enabled = false },
  panel = { enabled = false },
  filetypes = {
    yaml = true,
  },
  copilot_node_command = os.getenv('HOME') .. '/.local/bin/mise-node-lts.sh',
  server = {
    type = 'nodejs',
    custom_server_filepath = vim.fn.expand("~/.local/share/nvim/mason/bin/copilot-language-server"),
  },
})
require("copilot_cmp").setup()

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
  performance = {
    fetching_timeout = 500,
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '20', '-p', '--no-ignore'}} },
    { name = 'buffer' },
    { name = "copilot", group_index = 2 },
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
    { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '10', '-p', '--no-ignore'}} },
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
    require('neotest-go')({
      recursive_run = true,
    }),
  },
  quickfix = {
    enabled = true,
    open = true
  },
  icons = {
    passed = "",
    running = "",
    skipped = "",
    unknown = "",
  },
})

-- quickfix
require("qf_helper").setup()
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(args)
    wk.add({
      {'dd', ':Reject<cr>', buffer=args.buf}
    })
    -- vim.keymap.set('n', 'dd', ':Reject<cr>', { buffer = args.buf })
  end
})
-- mappings

-- GoToFile emulates how 'gf' works in Vim.
-- It will search for the file under the cursor using the configured vim 'path' option.
-- If it exists, it will open the existing file.
-- If it does not exist, it will open a new file
-- in the first directory that exists according to the 'vim' path option (found using :finddir).
function GoToFile()
  local cfile = vim.fn.findfile(vim.fn.expand("<cfile>"))
  if cfile == "" then
    local dir = vim.fn.finddir(vim.fn.expand("<cfile>:h"))
    local tail = vim.fn.expand("<cfile>:t")
    cfile = dir .. "/" .. tail
  end
  vim.cmd.edit(cfile)
end

-- Whichkey
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


-- Open help in a new tab
vim.api.nvim_create_user_command('Helptab', ':help <args> | wincmd T', { nargs = 1, complete = 'help' })

function QuitNoSession()
  vim.cmd(':SessionDelete')
  vim.cmd(':qa')
end

vim.api.nvim_create_user_command('Qas', QuitNoSession, {})

-- dap commands

-- dap-go
local dapGo = require('dap-go')
vim.api.nvim_create_user_command('DapGoTest', function() dapGo.debug_test() end, { bang = true })

-- dap-ui
local dapUI = require('dapui')
vim.api.nvim_create_user_command('DapUIOpen', function() dapUI.open({reset=true}) end, { bang = true })
vim.api.nvim_create_user_command('DapUIClose', function() dapUI.close() end, { bang = true })
vim.api.nvim_create_user_command('DapUIToggle', function() dapUI.toggle() end, { bang = true })
vim.api.nvim_create_user_command('DapUIEval', function() dapUI.eval() end, { bang = true })

-- neotest
local neotest = require('neotest')
vim.api.nvim_create_user_command('TestNearest', function() neotest.run.run() end, { bang = true })
vim.api.nvim_create_user_command('TestFile', function() neotest.run.run(vim.fn.expand("%")) end, { bang = true })
vim.api.nvim_create_user_command('TestDirectory', function() neotest.run.run(vim.fn.expand("%:p:h")) end, { bang = true })
vim.api.nvim_create_user_command('TestSuite', function() neotest.run.run(vim.fn.getcwd()) end, { bang = true })
vim.api.nvim_create_user_command('TestOpen', function() neotest.output.toggle() end, { bang = true })
vim.api.nvim_create_user_command('TestOutput', function() neotest.output_panel.toggle() end, { bang = true })
vim.api.nvim_create_user_command('TestSummary', function() neotest.summary.toggle() end, { bang = true })

-- dap mappings
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
    lualine_a = {'mode'},
    lualine_b = {'diagnostics'},
    lualine_c = {
      {
        'filename',
        path = 1,
      }
    },
    lualine_x = {'filetype', 'lsp_status'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
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

require("ibl").setup {}

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
  start_in_insert = true,
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

vim.api.nvim_create_user_command('ToggleTermSendCurrentBuffer', function(cmd) ToggleTerm_send_lines_to_terminal("current_buffer", false, cmd.args) end, { bang = true })

-- gitsigns
require('gitsigns').setup()

-- setup colorizer
require('colorizer').setup()

-- telescope
local actions = require("telescope.actions")
local telescope = require('telescope')
local telescopeBuiltin = require('telescope.builtin')

telescope.setup {
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
        ["<S-esc>"] = function ()
          -- exit insert mode
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-[>", true, false, true), "n", true)
        end,
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

telescope.load_extension('fzf')
require("telescope").load_extension('file_browser')
telescope.load_extension('dap')

vim.api.nvim_create_user_command('Diagnostics', function() telescopeBuiltin.diagnostics() end, {})
vim.api.nvim_create_user_command('DiagnosticsOpen', function() vim.diagnostic.open_float() end , {})
wk.add({
  mode =  'n',
  {'<c-p>', function() telescopeBuiltin.find_files() end, desc = 'Telescope find_files'},
  {'<m-o>', function() telescopeBuiltin.buffers() end, desc = 'Telescope buffers'},
  {'<c-b>', function() telescopeBuiltin.current_buffer_fuzzy_find() end, desc = 'Telescope current_buffer_fuzzy_find'},
  {'<c-g>', function() telescopeBuiltin.grep_string() end, desc = 'Telescope grep_string'},
  {'<m-;>', function() telescopeBuiltin.command_history() end, desc = 'Telescope command_history'},
  {'<m-c>', function() telescopeBuiltin.commands() end, desc = 'Telescope commands'},

  {'<leader>ff', function() telescopeBuiltin.find_files() end, desc = 'Telescope find_files'},
  {'<leader>fg', function() telescopeBuiltin.live_grep() end, desc = 'Telescope live_grep'},
  {'<leader>fB', function() telescopeBuiltin.buffers() end, desc = 'Telescope buffers'},
  {'<leader>fh', function() telescopeBuiltin.help_tags() end, desc = 'Telescope help_tags'},
  {'<leader>fr', function() telescopeBuiltin.registers() end, desc = 'Telescope registers'},
  {'<leader>fm', function() telescopeBuiltin.marks() end, desc = 'Telescope marks'},

  {'<leader>fb', function() telescope.extensions.file_browser.file_browser() end, desc = 'Telescope file_browser'},
})

-- Diagnostic keymaps
wk.add({
  mode =  'n',
  silent = true,
  {'<leader>d', function() telescopeBuiltin.diagnostics() end, desc = 'Diagnostics'},
  {'[d', function() vim.diagnostic.goto_prev() end, desc = 'Diagnostics goto previous'},
  {']d', function() vim.diagnostic.goto_next() end, desc = 'Diagnostics goto next'},
  {'<leader>q', function() vim.diagnostic.setloclist() end, desc = 'Diagnostics loclist'},
})

-- Custom parsers
local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
parser_config.cel = {
  install_info = {
    url = "https://github.com/bufbuild/tree-sitter-cel.git",
    files = {"src/parser.c"},
    branch = "main",
    generate_requires_npm = false,
    requires_generate_from_grammar = false,
  },
  filetype = "cel",
}

vim.filetype.add({
  extension = {
    cel = 'cel',
  },
})

-- setup treesitter
require'nvim-treesitter.configs'.setup {
  sync_install = false,
  auto_install = true,
  ensure_installed = {
    "c",
    "cel",
    "comment",
    "dockerfile",
    "go",
    "gomod",
    "gowork",
    "hcl",
    "html",
    "java",
    "javascript",
    "json",
    "kotlin",
    "latex",
    "lua",
    "make",
    "markdown",
    "proto",
    "python",
    "regex",
    "rust",
    "toml",
    "typescript",
    "vim",
    "yaml",
  },
  highlight = { enable = true },
  textobjects = {
    enable = true,
     select = {
      enable = true,
    },
  },
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
  'lazy',
  'mcphub',
  'markdown',
}

vim.api.nvim_create_autocmd({'FileType'}, {
  pattern = '*',
  callback = function()
    if vim.tbl_contains(whitespaceIgnoreFileTypes, vim.bo.filetype) then
      return
    end
    HighlightWhitespace()
  end
})


function ReplaceBufferLines(content)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
end

function ReplaceBufferString(content)
  ReplaceBufferLines(vim.split(content, '\n'))
end

function GetBufferLines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

function GetBufferString()
  return table.concat(GetBufferLines(), '\n')
end


function StripTrailingWhitespace()
  -- Get all lines in the buffer
  local lines = GetBufferLines()
  local changed = false

  for i, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    if stripped ~= line then
      lines[i] = stripped
      changed = true
    end
  end

  if changed then
    ReplaceBufferLines(lines)
  end
end


-- strip trailing whitespace
vim.api.nvim_create_autocmd({'BufWritePre'}, {
  pattern = '*',
  callback = function()
    -- Only strip if the b:noStripWhitespace variable isn't set
    if not vim.b.noStripWhitespace then
      StripTrailingWhitespace()
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd({'TextYankPost'}, {
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({higroup='IncSearch', timeout=300})
  end,
})

function RunCommand(binary, input, args)
  local cmd = {binary, args}

  vim.system(cmd, { stdin = input, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        ReplaceBufferString(result.stdout)
      else
        local cmd_str = table.concat(cmd, ' ')
        vim.api.nvim_echo({ { string.format("Error running %q: %s", cmd_str, result.stderr) } }, false, { err = true })
      end
    end)
  end)
end

-- JQ formats JSON in the current buffer
vim.api.nvim_create_user_command('JQ', function(cmd)
  local input = GetBufferLines()
  local args = cmd.args or '.'
  RunCommand('jq', input, args)
end, { nargs = '*', bang = true })

-- YQ formats YAML in the current buffer
vim.api.nvim_create_user_command('YQ', function(cmd)
  local input = GetBufferLines()
  local args = cmd.args or '.'
  RunCommand('yq', input, args)
end, { nargs = '*', bang = true })
