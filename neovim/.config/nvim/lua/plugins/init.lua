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

  { 'szw/vim-maximizer' },
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
      suppressed_dirs = { '~/', '~/projects', '~/Downloads', '/' },
      session_lens = {
        load_on_setup = false,
      },
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
