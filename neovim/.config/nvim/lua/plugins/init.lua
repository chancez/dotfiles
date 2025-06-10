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
  { 'norcalli/nvim-colorizer.lua',  event = 'VeryLazy', config = true },
  { 'kyazdani42/nvim-web-devicons', lazy = true },

  {
    'preservim/tagbar',
    cmd = 'TagbarToggle',
    keys = {
      { '<m-e>', ':TagbarToggle<CR>', { silent = true } },
    }
  },

  {
    'nvim-lualine/lualine.nvim',
    event = "VeryLazy",
    dependencies = { 'kyazdani42/nvim-web-devicons', lazy = true },
    opts = {
      options = { theme = 'onedark' },
      extensions = { 'toggleterm' },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'diagnostics' },
        lualine_c = {
          {
            'filename',
            path = 1,
          }
        },
        lualine_x = { 'filetype', 'lsp_status' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
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
        lualine_z = { 'tabs' }
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
  { 'chentoast/marks.nvim',    event = "VeryLazy", opts = { default_mappings = false } },

  -- utilities that leverage vim verbs
  { 'tpope/vim-repeat' },
  { 'tpope/vim-unimpaired' },
  { 'tpope/vim-surround' },

  -- utilities
  {
    'tpope/vim-commentary',
    keys = {
      { '<M-/>', ':Commentary<CR>', mode = { 'n', 'v' }, { silent = true } },
    }
  },
  { 'tpope/vim-eunuch' },
  {
    'junegunn/vim-easy-align',
    keys = {
      -- easy align
      { 'ga', '<Plug>(EasyAlign)', desc = 'Easy align', mode = { 'n', 'x' } },
    }
  },
  {
    'folke/which-key.nvim',
    event = "VeryLazy",
    cmd = 'WhichKey',
    keys = {
      { '<leader>w', ':WhichKey<CR>', desc = 'Open WhichKey', mode = 'n', { silent = true } },
    },
    opts = {
      win = {
        zindex = 2000 -- set higher than cmp so that which key is on top
      }
    },
    dependencies = { 'kyazdani42/nvim-web-devicons', opt = true }
  },
  { 'windwp/nvim-autopairs', event = "InsertEnter", opts = { check_ts = true } },

  {
    'szw/vim-maximizer',
    keys = {
      { '<c-w>0', ':MaximizerToggle<CR>', mode = { 'n' } },
    },
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
    keys = {
      { '<leader>c', function() require('osc52').copy_operator() end, desc = 'Copy to clipboard with OSC52' },
      { '<leader>c', function() require('osc52').copy_visual() end,   desc = 'Copy to clipboard with OSC52', mode = 'v' },
    },
    opts = {}
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
  { 'towolf/vim-helm',       ft = 'helm' },
}
