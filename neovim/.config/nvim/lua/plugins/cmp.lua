return {
  'saghen/blink.cmp',
  dependencies = {
    'rafamadriz/friendly-snippets',
    'fang2hou/blink-copilot',
  },
  version = '1.*',
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      preset = 'enter',
      ['<C-k>'] = { 'select_prev', 'fallback' },
      ['<C-j>'] = { 'select_next', 'fallback' },
      -- Jump between snippet placeholders if a snippet is active, otherwise jump to the next item in the completion menu
      ['<Tab>'] = { 'snippet_forward', 'select_next', 'fallback' },
      ['<S-Tab>'] = { 'snippet_backward', 'select_prev', 'fallback' },
      ['<CR>'] = { 'select_and_accept', 'fallback' },
      -- Trigger completion menu showing only copilot suggestions
      ['<C-l>'] = {
        function(cmp)
          cmp.show({ providers = { 'copilot' } })
        end
      },
    },
    appearance = {
      nerd_font_variant = 'mono'
    },
    completion = {
      list = {
        selection = {
          preselect = true,
          auto_insert = false,
        },
      },
      menu = {
        auto_show = true,
      },
      ghost_text = {
        enabled = true,
      },
      documentation = {
        auto_show = true,
      },
    },
    cmdline = {
      enabled = true,
      completion = {
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          auto_show = true,
        },
      },
      keymap = {
        preset = 'inherit',
        ['<S-Tab>'] = { 'insert_prev' },
        ['<Tab>'] = { 'insert_next' },
        ['<CR>'] = { 'accept_and_enter', 'fallback' },
      },
    },
    sources = {
      default = { 'copilot', 'lsp', 'path', 'snippets', 'buffer' },
      providers = {
        cmdline = {
          min_keyword_length = function(ctx)
            -- when typing a command, only show when the keyword is 3 characters or longer
            if ctx.mode == 'cmdline' and string.find(ctx.line, ' ') == nil then return 3 end
            return 0
          end
        },
        copilot = {
          name = "copilot",
          module = "blink-copilot",
          score_offset = 100,
          async = true,
        },
        buffer = {
          opts = {
            enable_in_ex_commands = true,
          },
        },
      },
    },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
      -- max_typos = 0,
      sorts = {
        'exact',
        'score',
        'sort_text',
      },
    },
  },
  opts_extend = { "sources.default" }
}
