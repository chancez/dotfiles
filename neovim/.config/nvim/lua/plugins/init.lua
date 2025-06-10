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

  -- search
  {
    'nvim-telescope/telescope.nvim',
    event = "VeryLazy",
    dependencies = {
      'nvim-lua/popup.nvim',
      'nvim-telescope/telescope-frecency.nvim',
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      "nvim-telescope/telescope-file-browser.nvim",
      { "nvim-telescope/telescope-dap.nvim", dependencies = { 'mfussenegger/nvim-dap' }},
      'nvim-telescope/telescope-symbols.nvim',
    },
    config = function ()
      local actions = require("telescope.actions")
      local telescope = require('telescope')

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

      local wk = require("which-key")
      local telescopeBuiltin = require('telescope.builtin')

      vim.api.nvim_create_user_command('Diagnostics', function() telescopeBuiltin.diagnostics() end, {})
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
        {'<leader>d', function() telescopeBuiltin.diagnostics() end, desc = 'Diagnostics'},

        {'<leader>fb', function() telescope.extensions.file_browser.file_browser() end, desc = 'Telescope file_browser'},
      })

    end
  },

  -- treesitter
  {
    'nvim-treesitter/nvim-treesitter',
    event = { "BufReadPost", "BufNewFile", "BufWritePre", "VeryLazy" },
    dependencies = {
      'nvim-treesitter/nvim-treesitter-refactor',
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
    opts = {
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
          lookahead = true,
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
          },
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
      --
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
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { "BufReadPost", "BufNewFile", "BufWritePre", "VeryLazy" },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
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
     }
  },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    config = function()
      require("plugins.configs.lspconfig").setup()
    end,
  },
  {
    'ray-x/lsp_signature.nvim',
    opts = {
      zindex = 50,
      bind = true, -- This is mandatory, otherwise border config won't get registered.
      handler_opts = {
        border = "rounded"
      },
      toggle_key = "<M-x>",
      floating_window_off_x = 60,
    }
  },
  { 'onsails/lspkind-nvim' },
  { 'j-hui/fidget.nvim', config = true },
  {
    'williamboman/mason.nvim',
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗"
        }
      }
    }
  },
  {
      "mason-org/mason-lspconfig.nvim",
      dependencies = {
          "mason-org/mason.nvim",
          "neovim/nvim-lspconfig",
      },
      config = function ()
        local serverNames = require("plugins.configs.lspconfig").server_names
        require("mason-lspconfig").setup({
          ensure_installed = serverNames,
          automatic_installation = true,
          automatic_enable = true,
        })
      end
  },

  -- debug adapter protocol
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      { 'rcarriga/nvim-dap-ui', dependencies = {"nvim-neotest/nvim-nio" }, config = true },
      { 'leoluz/nvim-dap-go', config = true },
    },
  },

  -- autocomplete
  {
    'hrsh7th/nvim-cmp', -- Autocompletion plugin
    event = {"InsertEnter", "CmdlineEnter"},
    dependencies = {
      'hrsh7th/cmp-cmdline', -- cmdline source
      'hrsh7th/cmp-nvim-lsp', -- LSP source
      'hrsh7th/cmp-path', -- path source
      'hrsh7th/cmp-buffer', -- buffer source
      { 'tzachar/cmp-fuzzy-path', dependencies = {'tzachar/fuzzy.nvim'} }, -- fuzzy path source
      {
        'zbirenbaum/copilot-cmp', dependencies = {'zbirenbaum/copilot.lua'},
        config = function ()
          require("copilot_cmp").setup()
        end
      },
      { 'saadparwaiz1/cmp_luasnip', dependencies = { 'L3MON4D3/LuaSnip' } }, -- Snippets source for nvim-cmp
    },
    config = function()
      local cmp = require 'cmp'
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local luasnip = require("luasnip")

      require("luasnip/loaders/from_vscode").lazy_load()

      cmp.event:on( 'confirm_done', cmp_autopairs.on_confirm_done({  map_char = { tex = '' } }))

      ---@diagnostic disable-next-line: redundant-parameter
      cmp.setup({
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
      })

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
    end
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
