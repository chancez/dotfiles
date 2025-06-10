return {
  {
    "nvim-neotest/neotest",
    cmd = {
      'Neotest',
      'TestNearest',
      'TestFile',
      'TestDirectory',
      'TestSuite',
      'TestOpen',
      'TestOutput',
      'TestSummary',
    },
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

      local neotest = require('neotest')

      neotest.setup({
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

      vim.api.nvim_create_user_command('TestNearest', function() neotest.run.run() end, { bang = true })
      vim.api.nvim_create_user_command('TestFile', function() neotest.run.run(vim.fn.expand("%")) end, { bang = true })
      vim.api.nvim_create_user_command('TestDirectory', function() neotest.run.run(vim.fn.expand("%:p:h")) end,
        { bang = true })
      vim.api.nvim_create_user_command('TestSuite', function() neotest.run.run(vim.fn.getcwd()) end, { bang = true })
      vim.api.nvim_create_user_command('TestOpen', function() neotest.output.toggle() end, { bang = true })
      vim.api.nvim_create_user_command('TestOutput', function() neotest.output_panel.toggle() end, { bang = true })
      vim.api.nvim_create_user_command('TestSummary', function() neotest.summary.toggle() end, { bang = true })
    end
  }
}
