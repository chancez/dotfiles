return {
  {
    'nvim-telescope/telescope.nvim',
    event = "VeryLazy",
    dependencies = {
      'nvim-lua/popup.nvim',
      'nvim-telescope/telescope-frecency.nvim',
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      "nvim-telescope/telescope-file-browser.nvim",
      { "nvim-telescope/telescope-dap.nvim", dependencies = { 'mfussenegger/nvim-dap' }},
      'nvim-telescope/telescope-symbols.nvim',
    },
    config = function ()
      local actions = require("telescope.actions")
      local telescope = require('telescope')

      telescope.setup {
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          file_browser = {
            theme = "ivy",
            -- disables netrw and use telescope-file-browser in its place
            hijack_netrw = true,
          },
        },
        defaults = require('telescope.themes').get_ivy {
          layout_config = {
            scroll_speed = 5,
          },
          mappings = {
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
              ["<M-k>"] = actions.preview_scrolling_up,
              ["<M-j>"] = actions.preview_scrolling_down,
              -- we want ctrl-u to be clear the prompt, so disable the default binding
              ["<C-u>"] = false,
              -- disable c-d because we don't have c-u mapped
              ["<C-d>"] = false,
              ["<esc>"] = actions.close,
              ["<S-esc>"] = function ()
                -- exit insert mode
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-[>", true, false, true), "n", true)
              end,
              ["<C-h>"] = "which_key",
              ["<C-s>"] = actions.cycle_previewers_next,
              ["<C-a>"] = actions.cycle_previewers_prev,

            },
            n = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
            },
          }
        },
        pickers = {
          find_files = {
            find_command = { 'rg', '--files', '--hidden', '--no-binary' },
          },
          buffers = {
            ignore_current_buffer = true,
            sort_mru = true,
          },
        },
      }

      telescope.load_extension('fzf')
      require("telescope").load_extension('file_browser')
      telescope.load_extension('dap')

      local wk = require("which-key")
      local telescopeBuiltin = require('telescope.builtin')

      vim.api.nvim_create_user_command('Diagnostics', function() telescopeBuiltin.diagnostics() end, {})
      wk.add({
        mode =  'n',
        {'<c-p>', function() telescopeBuiltin.find_files() end, desc = 'Telescope find_files'},
        {'<m-o>', function() telescopeBuiltin.buffers() end, desc = 'Telescope buffers'},
        {'<c-b>', function() telescopeBuiltin.current_buffer_fuzzy_find() end, desc = 'Telescope current_buffer_fuzzy_find'},
        {'<c-g>', function() telescopeBuiltin.grep_string() end, desc = 'Telescope grep_string'},
        {'<m-;>', function() telescopeBuiltin.command_history() end, desc = 'Telescope command_history'},
        {'<m-c>', function() telescopeBuiltin.commands() end, desc = 'Telescope commands'},

        {'<leader>ff', function() telescopeBuiltin.find_files() end, desc = 'Telescope find_files'},
        {'<leader>fg', function() telescopeBuiltin.live_grep() end, desc = 'Telescope live_grep'},
        {'<leader>fB', function() telescopeBuiltin.buffers() end, desc = 'Telescope buffers'},
        {'<leader>fh', function() telescopeBuiltin.help_tags() end, desc = 'Telescope help_tags'},
        {'<leader>fr', function() telescopeBuiltin.registers() end, desc = 'Telescope registers'},
        {'<leader>fm', function() telescopeBuiltin.marks() end, desc = 'Telescope marks'},
        {'<leader>d', function() telescopeBuiltin.diagnostics() end, desc = 'Diagnostics'},

        {'<leader>fb', function() telescope.extensions.file_browser.file_browser() end, desc = 'Telescope file_browser'},
      })

    end
  },
}
