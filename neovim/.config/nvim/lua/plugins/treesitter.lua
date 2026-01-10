return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = "main",
    lazy = false,
    build = ':TSUpdate',
    opts = {},
    config = function(_, opts)
      local ts = require('nvim-treesitter')

      -- https://github.com/nvim-treesitter/nvim-treesitter#adding-custom-languages
      vim.api.nvim_create_autocmd('User', {
        pattern = 'TSUpdate',
        callback = function()
          -- Custom parsers
          ---@diagnostic disable-next-line: missing-fields
          require('nvim-treesitter.parsers').cel = {
            ---@diagnostic disable-next-line: missing-fields
            install_info = {
              url = "https://github.com/bufbuild/tree-sitter-cel.git",
              files = { "src/parser.c" },
              branch = "main",
              generate_requires_npm = false,
              requires_generate_from_grammar = false,
            },
          }

          ---@diagnostic disable-next-line: missing-fields
          require('nvim-treesitter.parsers').godoc = {
            ---@diagnostic disable-next-line: missing-fields
            install_info = {
              url = "https://github.com/fredrikaverpil/tree-sitter-godoc",
              files = { "src/parser.c" },
              version = "*",
            },
            filetype = "godoc",
          }
        end
      })

      vim.filetype.add({
        extension = {
          cel = 'cel',
        },
      })
      vim.treesitter.language.register('godoc', 'godoc')
      vim.treesitter.language.register('bash', { 'zsh' })

      local filetypes = {
        "bash",
        "c",
        "comment",
        "dockerfile",
        "go",
        "gomod",
        "gowork",
        "hcl",
        "html",
        "java",
        "javascript",
        "json",
        "kotlin",
        "latex",
        "lua",
        "make",
        "markdown",
        "nim",
        "proto",
        "python",
        "regex",
        "rust",
        "toml",
        "typescript",
        "vim",
        "yaml",
        -- Custom parsers
        "cel",
        "godoc",
      }

      ts.setup(opts)
      ts.install(filetypes)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function() vim.treesitter.start() end,
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { "BufReadPost", "BufNewFile", "BufWritePre", "VeryLazy" },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      enable = true,
      multiwindow = true,
      patterns = {
        json = {
          "object",
          "pair",
        },
        yaml = {
          "block_mapping_pair",
          "block_sequence_item",
        },
        toml = {
          "table",
          "pair",
        },
        markdown = {
          "section",
        },
      },
    }
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      select = {
        -- Automatically jump forward to textobj, similar to targets.vim
        lookahead = true,
      },
      move = {
        set_jumps = true,
      },
    },
    config = function(_, opts)
      require("nvim-treesitter-textobjects").setup(opts)
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

      local desc_from_query = function(query)
        return query:sub(2):gsub('(%a+).(%a+)', '%2 %1')
      end

      local set_query_keymap = function(mode, f, keys, query)
        vim.keymap.set(mode, keys, function()
          f(query, "textobjects")
        end, { desc = desc_from_query(query) })
      end

      local set_query_keymaps = function(mode, f, mappings)
        for keys, query in pairs(mappings) do
          set_query_keymap(mode, f, keys, query)
        end
      end

      local keymaps = {
        {
          f = select.select_textobject,
          modes = { "o", "x" },
          mappings = {
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            ['ib'] = '@block.inner',
            ['ab'] = '@block.outer',
            ['al'] = '@loop.outer',
            ['il'] = '@loop.inner',
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
            ['is'] = '@statement.outer',
          },
        },
        {
          f = move.goto_next_start,
          modes = { "n", "x", "o" },
          mappings = {
            [']f'] = '@function.outer',
            [']c'] = '@class.outer',
            [']b'] = '@block.outer',
            [']l'] = '@loop.outer',
          },
        },
        {
          f = move.goto_previous_start,
          modes = { "n", "x", "o" },
          mappings = {
            ['[f'] = '@function.outer',
            ['[c'] = '@class.outer',
            ['[b'] = '@block.outer',
            ['[l'] = '@loop.outer',
          },
        },
      }

      for _, keymap in ipairs(keymaps) do
        set_query_keymaps(keymap.modes, keymap.f, keymap.mappings)
      end
    end,
  },
  { 'windwp/nvim-ts-autotag', dependencies = { 'nvim-treesitter/nvim-treesitter' }, config = true },
}
