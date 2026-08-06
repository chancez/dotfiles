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
}
