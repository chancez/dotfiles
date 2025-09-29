return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = "main",
    lazy = false,
    dependencies = {
      -- 'nvim-treesitter/nvim-treesitter-refactor',
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    build = ':TSUpdate',
    opts = {
      highlight = { enable = true },
      textobjects = {
        enable = true,
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
          },
        },
      },
    },
    config = function(_, opts)
      local ts = require('nvim-treesitter')
      local parsers = require "nvim-treesitter.parsers"
      ts.setup(opts)

      -- Custom parsers
      parsers.cel = {
        install_info = {
          url = "https://github.com/bufbuild/tree-sitter-cel.git",
          files = { "src/parser.c" },
          branch = "main",
          generate_requires_npm = false,
          requires_generate_from_grammar = false,
        },
      }

      vim.filetype.add({
        extension = {
          cel = 'cel',
        },
      })

      local filetypes = {
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
        "proto",
        "python",
        "regex",
        "rust",
        "toml",
        "typescript",
        "vim",
        "yaml",
        "cel",
      }

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

  { 'windwp/nvim-ts-autotag', dependencies = { 'nvim-treesitter/nvim-treesitter' }, config = true },
}
