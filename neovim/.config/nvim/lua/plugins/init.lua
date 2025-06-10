return {
  -- visual
  {
    'navarasu/onedark.nvim',
    priority = 1000,
    config = function()
      -- colorscheme
      require('onedark').setup {
        style = 'dark'
      }
      require('onedark').load()
    end
  },
  { 'norcalli/nvim-colorizer.lua', event = 'VeryLazy', config = true },
  { 'kyazdani42/nvim-web-devicons', lazy = true },

  { 'preservim/tagbar', cmd = 'TagbarToggle' },

  {
    'nvim-lualine/lualine.nvim',
    event = "VeryLazy",
    dependencies = { 'kyazdani42/nvim-web-devicons', lazy = true },
    opts = {
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
  },

  { 'lewis6991/gitsigns.nvim', event = "VeryLazy", dependencies = { 'nvim-lua/plenary.nvim' }, opts = {} },
  {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      ---@module "ibl"
      ---@type ibl.config
      opts = {},
  },
  { 'chentoast/marks.nvim', event = "VeryLazy", opts = { default_mappings = false } },

  -- debug adapter protocol
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      { 'rcarriga/nvim-dap-ui', dependencies = {"nvim-neotest/nvim-nio" }, config = true },
      { 'leoluz/nvim-dap-go', config = true },
    },
  },

  -- AI
  {
    'zbirenbaum/copilot.lua',
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
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
    }
  },

  {
    "olimorris/codecompanion.nvim",
    cmd = {"CodeCompanion", "CodeCompanionChat", "CodeCompanionCmd", "CodeCompanionActions"},
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
        opts = {
          cmd = 'mcp-hub'
        }
      },
    },
  },

  {
    'L3MON4D3/LuaSnip',
    config = function()
      require("luasnip/loaders/from_vscode").lazy_load()
      local luasnip = require 'luasnip'
      luasnip.config.set_config {
        history = true,
        updateevents = "TextChanged,TextChangedI"
      }
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
    event = "VeryLazy",
    opts = {},
    dependencies = {'kyazdani42/nvim-web-devicons', opt = true}
  },
  { 'windwp/nvim-autopairs', opts = { check_ts = true } },
  { 'windwp/nvim-ts-autotag', dependencies = { 'nvim-treesitter/nvim-treesitter' }, config = true },
  {
    'akinsho/toggleterm.nvim',
    opts = {
      open_mapping = '<c-t>',
      start_in_insert = true,
    },
    config = function (_, opts)
      local toggleterm = require("toggleterm")
      toggleterm.setup(opts)

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
    end
  },
  { 'szw/vim-maximizer' },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-go",
    },
    config = function()
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
    end
  },
  { 'nicwest/vim-camelsnek' },
  {
    'stevearc/qf_helper.nvim',
    config = function()
      require('qf_helper').setup()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "qf",
        callback = function(args)
          vim.keymap.set('n', 'dd', ':Reject<cr>', { buffer = args.buf })
        end
      })
    end
  },
  {
    'ojroques/nvim-osc52',
    config = function (_, opts)
      local osc52 = require('osc52')
      osc52.setup(opts)

      local wk = require("which-key")
      wk.add({
        {'<leader>c', function() osc52.copy_operator() end, desc = 'Copy to clipboard with OSC52'},
        {'<leader>c', function() osc52.copy_visual() end, desc = 'Copy to clipboard with OSC52', mode='v'},
      })
    end
  },
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
  {
    'mg979/vim-visual-multi',
    init = function()
      vim.g.VM_custom_remaps = {
        ['<c-p>'] = 'Q', -- map c-p to previous
        ['<c-x>'] = 'q', -- map c-x to skip
      }
      vim.g.VM_maps = {
        ["I BS"] = '', -- disable backspace mapping
      }
    end,
  },

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
}
