return {
  {
    'lewis6991/gitsigns.nvim',
    event = "VeryLazy",
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require('gitsigns')

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']g', function()
          if vim.wo.diff then
            vim.cmd.normal({ ']c', bang = true })
          else
            gitsigns.nav_hunk('next', { target = 'all' })
          end
        end, { desc = 'Next hunk' })

        map('n', '[g', function()
          if vim.wo.diff then
            vim.cmd.normal({ '[c', bang = true })
          else
            gitsigns.nav_hunk('prev', { target = 'all' })
          end
        end, { desc = 'Previous hunk' })
      end,
    },
  },

  -- git
  { 'tpope/vim-fugitive' },
  { 'tpope/vim-rhubarb' },
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    -- Load on octo:// buffers. octo:// URIs aren't real files, so BufRead never
    -- fires for them; BufReadCmd is the event octo itself hooks to populate the
    -- buffer, and lazy re-fires it after loading the plugin.
    event = "BufReadCmd octo://*",
    opts = {
      -- or "fzf-lua" or "snacks" or "default"
      picker = "telescope",
      -- bare Octo command opens picker of commands
      enable_builtin = true,
      default_remote = { "upstream", "origin", "isovalent" },
      mappings = {
        review_diff = {
          toggle_viewed = { lhs = "<c-space>", desc = "toggle viewer viewed state" },
        },
        file_panel = {
          toggle_viewed = { lhs = "<c-space>", desc = "toggle viewer viewed state" },
        },
      },
    },
    keys = {
      {
        "<leader>oi",
        "<CMD>Octo issue list<CR>",
        desc = "List GitHub Issues",
      },
      {
        "<leader>op",
        "<CMD>Octo pr list<CR>",
        desc = "List GitHub PullRequests",
      },
      {
        "<leader>od",
        "<CMD>Octo discussion list<CR>",
        desc = "List GitHub Discussions",
      },
      {
        "<leader>on",
        "<CMD>Octo notification list<CR>",
        desc = "List GitHub Notifications",
      },
      {
        "<leader>os",
        function()
          require("octo.utils").create_base_search_command { include_current_repo = true }
        end,
        desc = "Search GitHub",
      },
      {
        "<leader>or",
        "<CMD>Octo review<CR>",
        desc = "Review current PR",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons", -- optional if file_panel.icons is a function
    },
  }
}
