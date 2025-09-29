return {
  {
    "nvim-neotest/neotest",
    cmd = {
      'Neotest',
    },
    keys = {
      { "<leader>ta", function() require("neotest").run.attach() end,                                     desc = "[t]est [a]ttach" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,                      desc = "[t]est run [f]ile" },
      { "<leader>tA", function() require("neotest").run.run(vim.uv.cwd()) end,                            desc = "[t]est [A]ll files" },
      { "<leader>tS", function() require("neotest").run.run({ suite = true }) end,                        desc = "[t]est [S]uite" },
      { "<leader>tn", function() require("neotest").run.run() end,                                        desc = "[t]est [n]earest" },
      { "<leader>tl", function() require("neotest").run.run_last() end,                                   desc = "[t]est [l]ast" },
      { "<leader>ts", function() require("neotest").summary.toggle() end,                                 desc = "[t]est [s]ummary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "[t]est [o]utput" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end,                            desc = "[t]est [O]utput panel" },
      { "<leader>tt", function() require("neotest").run.stop() end,                                       desc = "[t]est [t]erminate" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "fredrikaverpil/neotest-golang",
        version = "*",
        dependencies = {
          "leoluz/nvim-dap-go",
        },
      },
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
          require('neotest-golang')({
            runner = "gotestsum",
            warn_test_name_dupes = false,
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
  }
}
