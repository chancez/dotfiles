local M = {}

-- Insert runtime_path of neovim lua files for LSP
local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, 'lua/?.lua')
table.insert(runtime_path, 'lua/?/init.lua')

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
  vim.api.nvim_buf_create_user_command(bufnr, 'LspFixAll', function() LspFixAll() end, { bang = true })

  -- formatting
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_buf_create_user_command(bufnr, 'LspFormat', function() vim.lsp.buf.format() end, { bang = true })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspOrgImports', function() LspOrgImports() end, { bang = true })
    vim.api.nvim_create_augroup('CodeFormat', { clear = false })
    vim.api.nvim_create_autocmd({'BufWritePre'}, {
      group = 'CodeFormat',
      buffer = bufnr,
      desc = 'Format code on save',
      callback = function()
        LspOrgImports()
        vim.lsp.buf.format()
      end,
    })
  end

  local map = vim.keymap.set

  map('n', '<leader>rn', '<cmd>LspRename<CR>', {desc = 'LspRename', silent = true, buffer = bufnr})
  map('n', 'gD', '<cmd>LspDeclaration<CR>', {desc = 'LspDeclaration', silent = true, buffer = bufnr})
  map('n', 'gd', '<cmd>LspDefinition<CR>', {desc = 'LspDefinition', silent = true, buffer = bufnr})
  map('n', '<leader>D', '<cmd>LspTypeDefinition<CR>', {desc = 'LspTypeDefinition', silent = true, buffer = bufnr})
  map('n', 'gr', '<cmd>LspReferences<CR>', {desc = 'LspReferences', silent = true, buffer = bufnr})
  map('n', 'gi', '<cmd>LspImplementation<CR>', {desc = 'LspImplementation', silent = true, buffer = bufnr})

  map('n', '<leader>ca', '<cmd>LspCodeAction<CR>', {desc = 'LspCodeAction', silent = true, buffer = bufnr})
  map('n', 'K', '<cmd>LspHover<CR>', {desc = 'LspHover', silent = true, buffer = bufnr})
  map('n', '<C-k>', '<cmd>LspSignatureHelp<CR>', {desc = 'LspSignatureHelp', silent = true, buffer = bufnr})

  map('n', '<leader>wa', '<cmd>LspAddWorkspaceFolder<CR>', {desc = 'LspAddWorkspaceFolder', silent = true, buffer = bufnr})
  map('n', '<leader>wr', '<cmd>LspRemoveWorkspaceFolder<CR>', {desc = 'LspRemoveWorkspaceFolder', silent = true, buffer = bufnr})
  map('n', '<leader>wl', '<cmd>LspListWorkspaceFolders<CR>', {desc = 'LspListWorkspaceFolders', silent = true, buffer = bufnr})

  map('n', '<leader>so', '<cmd>LspDocumentSymbols<CR>', {desc = 'LspDocumentSymbols', silent = true, buffer = bufnr})
  map('n', '<leader>sp', '<cmd>LspWorkspaceSymbols<CR>', {desc = 'LspWorkspaceSymbols', silent = true, buffer = bufnr})
  map('n', '<m-O>', '<cmd>LspDocumentSymbols<CR>', {desc = 'LspDocumentSymbols', silent = true, buffer = bufnr})
  map('n', '<m-p>', '<cmd>LspWorkspaceSymbols<CR>', {desc = 'LspWorkspaceSymbols', silent = true, buffer = bufnr})
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
    for k,v in pairs(server_specific_opts) do
      server_opts[k] = v
    end

    -- Server-specific settings. See `:help lsp-quickstart`
    vim.lsp.config(server_name, server_opts)
  end
end

return M
