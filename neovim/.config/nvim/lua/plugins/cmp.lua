return {
  'saghen/blink.cmp',
  dependencies = {
    'rafamadriz/friendly-snippets',
    'fang2hou/blink-copilot',
    {
      'saghen/blink.compat',
      -- use v2.* for blink.cmp v1.*
      version = '2.*',
      -- lazy.nvim will automatically load the plugin when it's required by blink.cmp
      lazy = true,
      -- make sure to set opts so that lazy.nvim calls blink.compat's setup
      opts = {},
    },
  },
  lazy = false,
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
          preselect = false,
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
        ['<Tab>'] = { 'insert_next', 'fallback' },
        ['<C-p>'] = { 'insert_prev' },
        ['<C-n>'] = { 'insert_next' },
        ['<CR>'] = { 'accept_and_enter', 'fallback' },
        ['<Up>'] = { 'fallback' },
        ['<Down>'] = { 'fallback' },
      },
    },
    sources = {
      default = {
        'copilot', 'lsp', 'path', 'snippets', 'buffer',
        "avante_commands", "avante_mentions", "avante_shortcuts", "avante_files",
      },
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
        avante_commands = {
          name = "avante_commands",
          module = "blink.compat.source",
          score_offset = 90, -- show at a higher priority than lsp
          opts = {},
        },
        avante_files = {
          name = "avante_files",
          module = "blink.compat.source",
          score_offset = 100, -- show at a higher priority than lsp
          opts = {},
        },
        avante_mentions = {
          name = "avante_mentions",
          module = "blink.compat.source",
          score_offset = 1000, -- show at a higher priority than lsp
          opts = {},
        },
        avante_shortcuts = {
          name = "avante_shortcuts",
          module = "blink.compat.source",
          score_offset = 1000, -- show at a higher priority than lsp
          opts = {},
        }
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
