return {
  {
    'hrsh7th/nvim-cmp', -- Autocompletion plugin
    event = {"InsertEnter", "CmdlineEnter"},
    dependencies = {
      'hrsh7th/cmp-cmdline', -- cmdline source
      'hrsh7th/cmp-nvim-lsp', -- LSP source
      'hrsh7th/cmp-path', -- path source
      'hrsh7th/cmp-buffer', -- buffer source
      { 'tzachar/cmp-fuzzy-path', dependencies = {'tzachar/fuzzy.nvim'} }, -- fuzzy path source
      {
        'zbirenbaum/copilot-cmp', dependencies = {'zbirenbaum/copilot.lua'},
        config = function ()
          require("copilot_cmp").setup()
        end
      },
      { 'saadparwaiz1/cmp_luasnip', dependencies = { 'L3MON4D3/LuaSnip' } }, -- Snippets source for nvim-cmp
    },
    config = function()
      local cmp = require 'cmp'
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local luasnip = require("luasnip")

      require("luasnip/loaders/from_vscode").lazy_load()

      cmp.event:on( 'confirm_done', cmp_autopairs.on_confirm_done({  map_char = { tex = '' } }))

      ---@diagnostic disable-next-line: redundant-parameter
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = {
          ['<Up>'] = cmp.mapping.select_prev_item(),
          ['<Down>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-j>'] = cmp.mapping.select_next_item(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.close(),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
          ['<Tab>'] = function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end,
          ['<S-Tab>'] = function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end,
        },
        performance = {
          fetching_timeout = 500,
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '20', '-p', '--no-ignore'}} },
          { name = 'buffer' },
          { name = "copilot", group_index = 2 },
        },
      })

      -- Use buffer source for `/`
      cmp.setup.cmdline('/', {
        mapping = {
          ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
          ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
          ['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
          ['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), {'i', 'c'}),
          ['<C-e>'] = cmp.mapping(cmp.mapping.close(), {'i', 'c'}),
        },
        sources = {
          { name = 'buffer' },
        }
      })

      -- Use cmdline & path source for ':'
      cmp.setup.cmdline(':', {
        mapping = {
          ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
          ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
          ['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i', 'c'}),
          ['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i', 'c'}),
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), {'i', 'c'}),
          ['<C-e>'] = cmp.mapping(cmp.mapping.close(), {'i', 'c'}),
        },
        sources = {
          { name = 'fuzzy_path', option = {fd_cmd = {'fd', '-d', '10', '-p', '--no-ignore'}} },
          { name = 'cmdline' },
        }
      })
    end
  },

}
