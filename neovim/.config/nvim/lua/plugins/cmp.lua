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
      -- Jump between different completion sources
      ['<C-S-k>'] = { function(cmp) cmp.select_prev({ jump_by = 'source_id' }) end },
      ['<C-S-j>'] = { function(cmp) cmp.select_next({ jump_by = 'source_id' }) end },
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
        draw = {
          components = {
            label_description = {
              width = { max = 100 },
            },
          },
        },
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
      },
      per_filetype = {
        AgenticInput = { 'agentic_slash', 'agentic_at', 'copilot', 'buffer' },
      },
      providers = {
        agentic_slash = {
          module = 'blink.cmp.sources.complete_func',
          name = 'AgenticSlash',
          enabled = function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            if cursor[1] ~= 1 then return false end
            local before = vim.api.nvim_get_current_line():sub(1, cursor[2])
            return before:match('^/[^%s]*$') ~= nil
          end,
          opts = { complete_func = function() return "v:lua.require'agentic.acp.slash_commands'.complete_func" end },
          transform_items = function(_, items)
            -- labelDetails.detail is usually "/", and results in completion
            -- entries looking like "command/ Description" and we just want
            -- "command Description", so we remove the detail field from
            -- labelDetails if it exists
            for _, item in ipairs(items) do
              if item.labelDetails then
                item.labelDetails.detail = nil
              end
            end
            return items
          end,
        },
        agentic_at = {
          module = 'blink.cmp.sources.complete_func',
          name = 'AgenticAt',
          enabled = function()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before = vim.api.nvim_get_current_line():sub(1, col)
            return (before:match('^@[^%s]*$') or before:match('[%s]@[^%s]*$')) ~= nil
          end,
          opts = { complete_func = function() return "v:lua.require'agentic.ui.file_picker'.complete_func" end },
          transform_items = function(_, items)
            -- labelDetails.detail is usually "@", and results in completion
            -- entries looking like "command@ Description" and we just want
            -- "command Description", so we remove the detail field from
            -- labelDetails if it exists
            for _, item in ipairs(items) do
              if item.labelDetails then
                item.labelDetails.detail = nil
              end
            end
            return items
          end,
        },
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
