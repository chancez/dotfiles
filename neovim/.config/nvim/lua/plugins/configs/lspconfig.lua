local M = {}

-- Insert runtime_path of neovim lua files for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, 'lua/?.lua')
table.insert(runtime_path, 'lua/?/init.lua')

local servers = {
  clangd                 = {
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- remove proto, handled by bufls
  },
  rust_analyzer          = {},
  pyright                = {},
  ts_ls                  = {},
  bashls                 = {
    bashIde = {
      enableSourceErrorDiagnostics = true,
      shellcheckPath = vim.fn.stdpath("data") .. "/mason/bin/shellcheck",
    }
  },
  dockerls               = {},
  jsonnet_ls             = {},
  sqlls                  = {},
  terraformls            = {},
  esbonio                = {}, -- Sphinx/RestructuredText
  jdtls                  = {},
  lua_ls                 = {
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
  gopls                  = {
    cmd = { "gopls", "serve" },
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
      },
    },
  },
  yamlls                 = {
    filetypes = { 'yaml', 'yaml.docker-compose' },
    settings = {
      yaml = {
        validate = false,
        format = {
          enable = false,
        },
        schemas = {
          ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        },
      }
    },
  },
  helm_ls                = {},
  buf_ls                 = {},
  kotlin_language_server = {},
  graphql                = {
    filetypes = { "typescript", "typescriptreact", "graphql" },
    settings = {
      ["graphql-config.load.legacy"] = true,
    }
  },
}

function LspOrgImports()
  vim.lsp.buf.code_action({
    ---@diagnostic disable-next-line: missing-fields
    context = {
      only = { 'source.organizeImports' },
    },
    apply = true,
  })
end

function LspFixAll()
  vim.lsp.buf.code_action({
    ---@diagnostic disable-next-line: missing-fields
    context = {
      only = { 'source.fixAll' },
    },
    apply = true,
  })
end

-- Setup LSP commands and keymaps
--
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client vim.lsp.Client client rpc object
local function lspAttach(bufnr, client)
  vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', { buf = bufnr })

  -- Define an lsp command that can be used in the command line
  local lspCommand = function(name, command)
    vim.api.nvim_buf_create_user_command(bufnr, name, command, { bang = true })
  end

  -- Map an lsp command to a keybinding. The command must already be defined.
  local mapLspCommand = function(cmd, lhs)
    local rhs = '<cmd>' .. cmd .. '<CR>'
    local desc = cmd
    local mode = 'n'
    vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true, buffer = bufnr })
  end

  -- Define an lsp command and map it to a keybinding
  local lspCommandMap = function(name, lhs, command)
    lspCommand(name, command)
    mapLspCommand(name, lhs)
  end

  lspCommandMap('LspRename', '<leader>rn', function() vim.lsp.buf.rename() end)
  lspCommandMap('LspDeclaration', 'gD', function() vim.lsp.buf.declaration() end)
  lspCommandMap('LspDefinition', 'gd', function() require("telescope.builtin").lsp_definitions({ fname_width = 75 }) end)
  lspCommandMap('LspTypeDefinition', '<leader>D', function() require("telescope.builtin").lsp_type_definitions() end)
  lspCommandMap('LspReferences', 'gr', function() require("telescope.builtin").lsp_references({ fname_width = 75 }) end)
  lspCommandMap('LspImplementation', 'gi', function() require("telescope.builtin").lsp_implementations() end)

  lspCommandMap('LspCodeAction', '<leader>ca', function() vim.lsp.buf.code_action() end)
  lspCommandMap('LspHover', 'K', function() vim.lsp.buf.hover() end)
  lspCommandMap('LspSignatureHelp', '<C-k>', function() vim.lsp.buf.signature_help() end)

  lspCommandMap('LspAddWorkspaceFolder', '<leader>wa', function() vim.lsp.buf.add_workspace_folder() end)
  lspCommandMap('LspRemoveWorkspaceFolder', '<leader>wr', function() vim.lsp.buf.remove_workspace_folder() end)
  lspCommandMap('LspListWorkspaceFolders', '<leader>wl',
    function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end)

  lspCommandMap('LspDocumentSymbols', '<m-O>', function() require("telescope.builtin").lsp_document_symbols() end)
  lspCommandMap('LspWorkspaceSymbols', '<m-p>',
    function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end)
  lspCommand('LspIncomingCalls', function() require("telescope.builtin").lsp_incoming_calls() end)
  lspCommand('LspOutgoingCalls', function() require("telescope.builtin").lsp_outgoing_calls() end)
  lspCommand('LspFixAll', function() LspFixAll() end)

  -- formatting
  if client.server_capabilities.documentFormattingProvider then
    lspCommand('LspFormat', function() vim.lsp.buf.format() end)
    lspCommand('LspOrgImports', function() LspOrgImports() end)
    vim.api.nvim_create_augroup('CodeFormat', { clear = false })
    vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
      group = 'CodeFormat',
      buffer = bufnr,
      desc = 'Format code on save',
      callback = function()
        -- Suppress No code actions available message
        -- https://github.com/neovim/neovim/issues/17758#issuecomment-1704694075
        local orignal = vim.notify
        vim.notify = function(msg, level, opts)
          if msg == 'No code actions available' then
            return
          end
          orignal(msg, level, opts)
        end
        LspOrgImports()
        vim.lsp.buf.format()
      end,
    })
  end
end

M.server_names = vim.tbl_keys(servers)

M.setup = function()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local bufnr = ev.buf
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      lspAttach(bufnr, client)
    end
  })


  for server_name, server_specific_opts in pairs(servers) do
    -- nvim-cmp supports additional completion capabilities
    local cmp_lsp = require('cmp_nvim_lsp')
    local capabilities = cmp_lsp.default_capabilities()
    local server_opts = {
      capabilities = capabilities,
      flags = {
        debounce_text_changes = 150,
      },
    }
    for k, v in pairs(server_specific_opts) do
      server_opts[k] = v
    end

    -- Server-specific settings. See `:help lsp-quickstart`
    vim.lsp.config(server_name, server_opts)
  end
end

return M
