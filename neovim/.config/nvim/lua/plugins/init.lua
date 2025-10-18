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
    ft = "qf",
    keys = {
      { "<leader>q", function() require("quicker").toggle() end, desc = "Toggle quickfix", },
    },
    opts = {
      follow = {
        enabled = true,
      },
      keys = {
        { ">", function() require("quicker").expand({ before = 2, after = 2, add_to_existing = true }) end, desc = "Expand quickfix context", },
        { "<", function() require("quicker").collapse() end,                                                desc = "Collapse quickfix context", },
      },
    },
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

  -- multicursor support like sublime text
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      set({ "v" }, "<c-n>", function() mc.matchAddCursor(1) end)
      set({ "v" }, "<c-a>", function() mc.visualToCursors() end)
      set({ "n", "v" }, "<c-s-a>", function() mc.matchAllAddCursors() end)

      -- Mappings defined in a keymap layer only apply when there are
      -- multiple cursors. This lets you have overlapping mappings.
      mc.addKeymapLayer(function(layerSet)
        layerSet({ "n", "v" }, "<c-x>", function() mc.matchSkipCursor(1) end)
        layerSet({ "n", "v" }, "<c-p>", function() mc.matchSkipCursor(-1) end)

        -- Map tab to escape in multi-cursor mode, which is how
        -- vim-visual-multi worked (hard to break habits)
        layerSet({ "n", "v" }, "<tab>", '<Esc>')

        -- Enable and clear cursors using escape.
        layerSet("n", "<esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end
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
  {
    "cuducos/yaml.nvim",
    ft = { "yaml", "yaml.helm-values" },
    cmd = {
      "YAMLView",
      "YAMLYank",
      "YAMLYankKey",
      "YAMLYankValue",
      "YAMLHighlight",
      "YAMLRemoveHighlight",
      "YAMLQuickfix",
      "YAMLTelescope",
    },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      ft = { "yaml", "yaml.helm-values" }
    },
  },
}
