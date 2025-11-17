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
    'nvim-lualine/lualine.nvim',
    event = "VeryLazy",
    dependencies = { 'kyazdani42/nvim-web-devicons', lazy = true },
    opts = {
      options = { theme = 'onedark' },
      extensions = { 'toggleterm' },
      sections = {
        lualine_a = { 'mode', 'g:viewport_active_mode' },
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

  {
    'tadaa/vimade',
    event = 'VeryLazy',
    opts = {
      recipe = { 'default', { animate = false } },
      ncmode = 'windows', -- fade/tint inactive windows
      fadelevel = 0.9,    -- 90% opaque for inactive windows
      tint = {
        -- bg = { rgb = { 0, 0, 0 }, intensity = 0.1 },       -- 10% black background
        fg = { rgb = { 120, 120, 120 }, intensity = 0.1 }, -- 10% grey foreground
      },
      link = {
        telescope = function(win, active)
          if active and active.buf_opts.filetype == 'TelescopePrompt' then
            return true
          end
          return false
        end,
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

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    keys = {
      { "<leader>j", mode = { "n", "x", "o" }, function() require("flash").jump() end,       desc = "Flash" },
      { "<leader>T", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "<c-s>",     mode = { "c" },           function() require("flash").toggle() end,     desc = "Toggle Flash Search" },
      vim.keymap.set({ "n", "x", "o" }, "<c-space>", function()
        require("flash").treesitter({
          actions = {
            ["<c-space>"] = "next",
            ["<BS>"] = "prev"
          }
        })
      end, { desc = "Treesitter incremental selection" })
    },
    opts = {
      modes = {
        char = {
          enabled = false,
        },
      },
    },
  },
  { 'windwp/nvim-autopairs', event = "InsertEnter", opts = { check_ts = true } },

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
  {
    "NStefan002/screenkey.nvim",
    lazy = false,
    version = "*", -- or branch = "main", to use the latest commit
  },

  -- git
  { 'tpope/vim-fugitive' },
  { 'tpope/vim-rhubarb' },
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
