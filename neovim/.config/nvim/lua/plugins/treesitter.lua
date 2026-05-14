--- Find the closest ancestor (or self) matching node_type.
local function find_ancestor(node, node_type)
  while node do
    if node:type() == node_type then
      return node
    end
    node = node:parent()
  end
end

--- Find a treesitter node for a text object selection.
--- Walks up from the cursor node looking for outer_type, then finds inner_type as a child.
local function find_ts_textobj_node(inner_type, outer_type, inner)
  local node = vim.treesitter.get_node()
  if not node then return nil end
  local target_type = inner and inner_type or outer_type
  local target = find_ancestor(node, target_type)
  if not target and inner then
    local outer = find_ancestor(node, outer_type)
    if outer then
      for child in outer:iter_children() do
        if child:type() == inner_type then
          return child
        end
      end
    end
  end
  return target
end

--- Visually select a treesitter node's range. Works in both x and o modes.
local function select_ts_node(node)
  local sr, sc, er, ec = node:range()
  -- Exit visual mode if we're in it (x-mode), so we can start a fresh selection.
  -- In operator-pending mode (o-mode), we skip this so the operator isn't cancelled.
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd([[execute "normal! \<Esc>"]])
  end
  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { er + 1, math.max(ec - 1, 0) })
end

--- Set up buffer-local text object keymaps that select treesitter nodes.
--- Overrides a built-in text object key (e.g. "`") for a specific filetype.
---@param buf number Buffer handle
---@param key string The character to override (e.g. "`")
---@param inner_type string Treesitter node type for inner selection
---@param outer_type string Treesitter node type for outer selection
local function setup_ts_textobj(buf, key, inner_type, outer_type)
  for _, mode in ipairs({ 'x', 'o' }) do
    for _, prefix in ipairs({ 'i', 'a' }) do
      local inner = prefix == 'i'
      local lhs = prefix .. key
      vim.keymap.set(mode, lhs, function()
        local node = find_ts_textobj_node(inner_type, outer_type, inner)
        if node then
          select_ts_node(node)
        else
          local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
          vim.api.nvim_feedkeys(keys, 'xn', false)
        end
      end, { buffer = buf, desc = prefix .. key .. " (treesitter)" })
    end
  end
end

-- Treesitter node text object overrides per filetype.
-- Each entry maps a key character to { inner = node_type, outer = node_type }.
local ts_textobj_overrides = {
  go = {
    ['`'] = { inner = 'raw_string_literal_content', outer = 'raw_string_literal' },
  },
}

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
        "diff",
        "dockerfile",
        "gitcommit",
        "go",
        "gomod",
        "gotmpl",
        "gowork",
        "hcl",
        "helm",
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
        "sql",
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

      -- Set up treesitter-based text object overrides per filetype
      for ft, overrides in pairs(ts_textobj_overrides) do
        vim.api.nvim_create_autocmd('FileType', {
          pattern = ft,
          callback = function(ev)
            for key, types in pairs(overrides) do
              setup_ts_textobj(ev.buf, key, types.inner, types.outer)
            end
          end,
        })
      end
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
            ['is'] = '@statement.inner',
            ['as'] = '@statement.outer',
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
