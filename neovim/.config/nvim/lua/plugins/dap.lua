return {
  {
    'mfussenegger/nvim-dap',
    cmd = {
      'DapGoTest',
      'DapUIOpen',
      'DapUIClose',
      'DapUIToggle',
      'DapUIEval',
    },
    keys = {
      { 'gtn', ':TestNearest<CR>',   { silent = true } },
      { 'gtf', ':TestFile<CR>',      { silent = true } },
      { 'gtd', ':TestDirectory<CR>', { silent = true } },
      { 'gts', ':TestSuite<CR>',     { silent = true } },
      { 'gto', ':TestOpen<CR>',      { silent = true } },
      { 'gtO', ':TestOutput<CR>',    { silent = true } },
      { 'gtS', ':TestSummary<CR>',   { silent = true } },
    },
    dependencies = {
      { 'rcarriga/nvim-dap-ui', dependencies = { "nvim-neotest/nvim-nio" }, config = true },
      { 'leoluz/nvim-dap-go',   config = true },
    },
    config = function()
      -- dap-go
      local dapGo = require('dap-go')
      vim.api.nvim_create_user_command('DapGoTest', function() dapGo.debug_test() end, { bang = true })

      -- dap-ui
      local dapUI = require('dapui')
      vim.api.nvim_create_user_command('DapUIOpen', function() dapUI.open({ reset = true }) end, { bang = true })
      vim.api.nvim_create_user_command('DapUIClose', function() dapUI.close() end, { bang = true })
      vim.api.nvim_create_user_command('DapUIToggle', function() dapUI.toggle() end, { bang = true })
      vim.api.nvim_create_user_command('DapUIEval', function() dapUI.eval() end, { bang = true })
    end
  }
}
