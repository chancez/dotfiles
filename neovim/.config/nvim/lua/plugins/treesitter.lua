return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- event = { "BufReadPost", "BufNewFile", "BufWritePre", "VeryLazy" },
    dependencies = {
      'nvim-treesitter/nvim-treesitter-refactor',
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    build = ':TSUpdate',
    opts = {
      sync_install = false,
      auto_install = true,
      ensure_installed = {
        "c",
        "cel",
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
      },
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
      require("nvim-treesitter.configs").setup(opts)
      --
      -- Custom parsers
      local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
      parser_config.cel = {
        install_info = {
          url = "https://github.com/bufbuild/tree-sitter-cel.git",
          files = {"src/parser.c"},
          branch = "main",
          generate_requires_npm = false,
          requires_generate_from_grammar = false,
        },
        filetype = "cel",
      }

      vim.filetype.add({
        extension = {
          cel = 'cel',
        },
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
