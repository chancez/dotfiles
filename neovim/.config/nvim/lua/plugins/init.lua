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
    'stevearc/quicker.nvim',
    event = "FileType qf",
    opts = {},
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
        picker = "telescope",
      },
      -- log_level = 'debug',
      -- git_use_branch_name = true,
      git_auto_restore_on_branch_change = true,
      git_use_branch_name = function(path)
        local lib = require("auto-session.lib")
        local cmd = string.format('git-current-branch %s', path or "")
        lib.logger.debug("git_get_branch_name: executing " .. cmd)
        local out = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          lib.logger.debug("git_get_branch_name: git failed with: " .. out)
          return nil
        end
        lib.logger.debug("git_get_branch_name: got branch: " .. out)
        return vim.fn.trim(out)
      end,
      no_restore_cmds = {
        -- If there is no existing session, clear out all buffers
        function(is_startup)
          if (is_startup) then
            return
          end
          local autosession = require('auto-session')
          local lib = require("auto-session.lib")
          lib.logger.debug("no_restore: checking for existing session")
          if not autosession.session_exists_for_cwd() then
            lib.logger.debug("no_restore: no existing session, clearing buffers before restoring")
            lib.conditional_buffer_wipeout(false)
          end
        end
      }
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
  {
    "ramilito/kubectl.nvim",
    version      = "2.*",
    dependencies = "saghen/blink.download",
    keys         = {
      { "<leader>k", function() require("kubectl").toggle({ tab = true }) end, desc = 'Toggle kubectl', mode = 'n', { silent = true } },
    },
    cmd          = { "Kubectl" },
    opts         = {}
  },
}
