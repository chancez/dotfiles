local util = require('config.util')

local M = {}

local auto_enable_servers = {
  clangd                 = {
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- remove proto, handled by bufls
  },
  rust_analyzer          = {},
  pyright                = {},
  ts_ls                  = {},
  bashls                 = {
    filetypes = { "bash", "sh", "zsh" },
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
  jsonls                 = {},
  taplo                  = {},
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


local install_only_servers = {
  "copilot",
}

local function LspOrgImports()
  vim.lsp.buf.code_action({
    ---@diagnostic disable-next-line: missing-fields
    context = {
      only = { 'source.organizeImports' },
    },
    apply = true,
  })
end

local function LspFixAll()
  vim.lsp.buf.code_action({
    ---@diagnostic disable-next-line: missing-fields
    context = {
      only = { 'source.fixAll' },
    },
    apply = true,
  })
end

-- Add a toggle for autoformatting
vim.g.autoFormat = true
vim.b.autoFormat = nil

local function LspToggleAutoFormat()
  vim.g.autoFormat = not vim.g.autoFormat
  local status = vim.g.autoFormat and "enabled" or "disabled"
  print("Auto-formatting on save " .. status)
end

local function LspToggleAutoFormatBuffer()
  vim.b.autoFormat = not vim.b.autoFormat
  local status = vim.b.autoFormat and "enabled" or "disabled"
  print("Auto-formatting on save for this buffer " .. status)
end

local function IsLspAutoFormatEnabled()
  -- Check if autoformatting is disabled for the filetype
  if vim.tbl_contains({ 'zsh' }, vim.bo.filetype) then
    return false
  end

  -- Check if autoformatting is disabled for the buffer
  if vim.b.autoFormat == nil then
    return vim.g.autoFormat
  else
    return vim.b.autoFormat
  end
end

-- Setup LSP commands and keymaps
--
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client vim.lsp.Client client rpc object
local function lspAttach(bufnr, client)
  vim.bo[bufnr].formatexpr = nil
  vim.bo[bufnr].formatprg = nil


  vim.api.nvim_set_option_value('omnifunc', 'v:lua.vim.lsp.omnifunc', { buf = bufnr })

  util.map_and_define_user_command('LspRename', '<leader>rn', function() vim.lsp.buf.rename() end, bufnr)
  util.map_and_define_user_command('LspDeclaration', 'gD', function() vim.lsp.buf.declaration() end, bufnr)
  util.map_and_define_user_command('LspDefinition', 'gd',
    function() require("telescope.builtin").lsp_definitions({ fname_width = 75 }) end, bufnr)
  util.map_and_define_user_command('LspTypeDefinition', '<leader>D',
    function() require("telescope.builtin").lsp_type_definitions() end, bufnr)
  util.map_and_define_user_command('LspReferences', 'gr',
    function() require("telescope.builtin").lsp_references({ fname_width = 75 }) end, bufnr)
  util.map_and_define_user_command('LspImplementation', 'gi',
    function() require("telescope.builtin").lsp_implementations() end, bufnr)

  util.map_and_define_user_command('LspCodeAction', '<leader>ca', function() vim.lsp.buf.code_action() end, bufnr)
  util.map_and_define_user_command('LspHover', 'K', function() vim.lsp.buf.hover() end, bufnr)
  util.map_and_define_user_command('LspSignatureHelp', '<C-k>', function() vim.lsp.buf.signature_help() end, bufnr)

  util.map_and_define_user_command('LspAddWorkspaceFolder', '<leader>wa',
    function() vim.lsp.buf.add_workspace_folder() end, bufnr)
  util.map_and_define_user_command('LspRemoveWorkspaceFolder', '<leader>wr',
    function() vim.lsp.buf.remove_workspace_folder() end, bufnr)
  util.map_and_define_user_command('LspListWorkspaceFolders', '<leader>wl',
    function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, bufnr)

  util.map_and_define_user_command('LspDocumentSymbols', '<m-O>',
    function() require("telescope.builtin").lsp_document_symbols() end, bufnr)
  util.map_and_define_user_command('LspWorkspaceSymbols', '<m-p>',
    function() require("telescope.builtin").lsp_dynamic_workspace_symbols() end, bufnr)
  vim.api.nvim_buf_create_user_command(bufnr, 'LspIncomingCalls',
    function() require("telescope.builtin").lsp_incoming_calls() end, {})
  vim.api.nvim_buf_create_user_command(bufnr, 'LspOutgoingCalls',
    function() require("telescope.builtin").lsp_outgoing_calls() end, {})
  vim.api.nvim_buf_create_user_command(bufnr, 'LspFixAll', function() LspFixAll() end, {})

  -- formatting
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_buf_create_user_command(bufnr, 'LspFormat', function() vim.lsp.buf.format() end, {})
    vim.api.nvim_buf_create_user_command(bufnr, 'LspOrgImports', function() LspOrgImports() end, {})
    vim.api.nvim_buf_create_user_command(bufnr, 'LspToggleAutoFormat', function() LspToggleAutoFormat() end, {})
    vim.api.nvim_buf_create_user_command(bufnr, 'LspToggleAutoFormatBuffer', function() LspToggleAutoFormat() end, {})

    vim.api.nvim_create_augroup('CodeFormat', { clear = false })
    vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
      group = 'CodeFormat',
      buffer = bufnr,
      desc = 'Format code on save',
      callback = function()
        -- Check if autoformatting is enabled
        if not IsLspAutoFormatEnabled() then
          return
        end
        vim.lsp.buf.format()
        -- TODO: Make this synchronous so we can run it before buf.format(). It
        -- has to go after, otherwise sometimes there's weird corruption issues
        -- when both write to a file at once.
        LspOrgImports()
      end,
    })
  end
end

local auto_install_servers = util.table_concat(vim.tbl_keys(auto_enable_servers), install_only_servers)

M.auto_install_servers = auto_install_servers

local ignored_filetypes = {
  'neotest-output-panel',
}

M.setup = function()
  -- Suppress No code actions available message
  -- https://github.com/neovim/neovim/issues/17758#issuecomment-1704694075
  local original_vim_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if msg == 'No code actions available' then
      return
    end
    original_vim_notify(msg, level, opts)
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local bufnr = ev.buf
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      local filetype = vim.bo[bufnr].filetype
      if vim.tbl_contains(ignored_filetypes, filetype) then
        return
      end
      lspAttach(bufnr, client)
    end
  })


  for server_name, server_specific_opts in pairs(auto_enable_servers) do
    local server_opts = {
      flags = {
        debounce_text_changes = 150,
      },
    }
    for k, v in pairs(server_specific_opts) do
      server_opts[k] = v
    end

    -- Server-specific settings. See `:help lsp-quickstart`
    vim.lsp.config(server_name, server_opts)
    vim.lsp.enable(server_name)
  end
end

return M
