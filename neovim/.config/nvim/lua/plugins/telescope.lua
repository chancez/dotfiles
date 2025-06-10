return {
  {
    'nvim-telescope/telescope.nvim',
    cmd = {
      'Telescope',
      'Diagnostics',
    },
    keys = {
      {'<c-p>', function() require('telescope.builtin').find_files() end, desc = 'Telescope find_files'},
      {'<m-o>', function() require('telescope.builtin').buffers() end, desc = 'Telescope buffers'},
      {'<c-b>', function() require('telescope.builtin').current_buffer_fuzzy_find() end, desc = 'Telescope current_buffer_fuzzy_find'},
      {'<c-g>', function() require('telescope.builtin').grep_string() end, desc = 'Telescope grep_string'},
      {'<m-;>', function() require('telescope.builtin').command_history() end, desc = 'Telescope command_history'},
      {'<m-c>', function() require('telescope.builtin').commands() end, desc = 'Telescope commands'},

      {'<leader>ff', function() require('telescope.builtin').find_files() end, desc = 'Telescope find_files'},
      {'<leader>fg', function() require('telescope.builtin').live_grep() end, desc = 'Telescope live_grep'},
      {'<leader>fB', function() require('telescope.builtin').buffers() end, desc = 'Telescope buffers'},
      {'<leader>fh', function() require('telescope.builtin').help_tags() end, desc = 'Telescope help_tags'},
      {'<leader>fr', function() require('telescope.builtin').registers() end, desc = 'Telescope registers'},
      {'<leader>fm', function() require('telescope.builtin').marks() end, desc = 'Telescope marks'},
      {'<leader>d', function() require('telescope.builtin').diagnostics() end, desc = 'Diagnostics'},
      {'<leader>fb', function() require('telescope').extensions.file_browser.file_browser() end, desc = 'Telescope file_browser'},
    },
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

      vim.api.nvim_create_user_command('Diagnostics', function() require('telescope.builtin').diagnostics() end, {})
    end,
  },
}
