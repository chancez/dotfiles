return {
  {
    'nvim-telescope/telescope.nvim',
    lazy = false,
    keys = {
      { '<c-p>',      function() require('telescope.builtin').find_files() end,                   desc = 'Telescope find_files' },
      { '<m-o>',      function() require('telescope.builtin').buffers() end,                      desc = 'Telescope buffers' },
      { '<c-b>',      function() require('telescope.builtin').current_buffer_fuzzy_find() end,    desc = 'Telescope current_buffer_fuzzy_find' },
      { '<c-g>',      function() require('telescope.builtin').grep_string() end,                  desc = 'Telescope grep_string' },
      { '<m-;>',      function() require('telescope.builtin').command_history() end,              desc = 'Telescope command_history' },
      { '<m-c>',      function() require('telescope.builtin').commands() end,                     desc = 'Telescope commands' },

      { '<leader>ff', function() require('telescope.builtin').find_files() end,                   desc = 'Telescope find_files' },
      { '<leader>fg', function() require('telescope.builtin').live_grep() end,                    desc = 'Telescope live_grep' },
      { '<leader>fB', function() require('telescope.builtin').buffers() end,                      desc = 'Telescope buffers' },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end,                    desc = 'Telescope help_tags' },
      { '<leader>fr', function() require('telescope.builtin').registers() end,                    desc = 'Telescope registers' },
      { '<leader>fm', function() require('telescope.builtin').marks() end,                        desc = 'Telescope marks' },
      { '<leader>fp', function() require('telescope.builtin').pickers() end,                      desc = 'Telescope previous pickers' },
      { '<leader>fd', function() require('telescope.builtin').diagnostics() end,                  desc = 'Telescope Diagnostics' },
      { '<leader>fb', function() require('telescope').extensions.file_browser.file_browser() end, desc = 'Telescope file_browser' },
      { '<leader>u',  function() require('telescope').extensions.undo.undo() end,                 desc = 'Telescope undo' },
    },
    dependencies = {
      'nvim-lua/popup.nvim',
      'nvim-telescope/telescope-frecency.nvim',
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      "nvim-telescope/telescope-file-browser.nvim",
      { "nvim-telescope/telescope-dap.nvim",        dependencies = { 'mfussenegger/nvim-dap' } },
      'nvim-telescope/telescope-symbols.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      "debugloop/telescope-undo.nvim",
    },
    config = function()
      local builtin = require("telescope.builtin")
      local actions = require("telescope.actions")
      local telescope = require('telescope')
      local action_state = require("telescope.actions.state")
      local fb_actions = require "telescope".extensions.file_browser.actions

      local recreate_picker = function(current_picker, opts)
        local picker = nil
        -- This is a hack but I cannot figure out how to get the current picker function and then re-run it with a different cwd
        if current_picker.prompt_title == 'Live Grep' then
          picker = builtin.live_grep
        elseif current_picker.prompt_title == 'Find Files' then
          picker = builtin.find_files
        end
        if picker == nil then
          print("Cannot refine this picker to a directory")
          return
        end
        picker(opts)
      end

      -- A stack of previous directories
      local previous_directories = {}

      -- Refine to directory of current buffer
      local refine_current_dir = function(prompt_bufnr)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local line = action_state.get_current_line()

        -- Get the directory of the buffer from before the picker was opened
        local buf = current_picker.original_bufnr
        local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~:.:h")

        -- Add current cwd to previous stack
        table.insert(previous_directories, current_picker.cwd)

        recreate_picker(current_picker, {
          results_title = dir,
          cwd = dir,
          default_text = line,
        })
      end

      -- Refine to parent directory of current cwd
      local refine_parent_dir = function(prompt_bufnr)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local line = action_state.get_current_line()

        local cwd = current_picker.cwd
        if cwd == nil then
          cwd = vim.fn.getcwd()
        end
        -- Add current cwd to previous stack
        table.insert(previous_directories, cwd)

        local parent_dir = vim.fn.fnamemodify(cwd .. "/..", ":~:.:h")

        recreate_picker(current_picker, {
          results_title = parent_dir,
          cwd = parent_dir,
          default_text = line,
        })
      end

      -- Refine to previous directory
      local refine_previous_dir = function(prompt_bufnr)
        -- Check if there is a previous directory to jump to
        if #previous_directories == 0 then
          return
        end

        -- Pop from previous dirs stack
        local previous_dir = table.remove(previous_directories)
        if not previous_dir then
          return
        end

        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local line = action_state.get_current_line()

        recreate_picker(current_picker, {
          results_title = previous_dir,
          cwd = previous_dir,
          default_text = line,
        })
      end

      local new_cmd_next_to_selection_action = function(cmd)
        return function(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- Get the directory of the currently selected entry
          local dir = vim.fn.fnamemodify(selection.path, ":~:.:h") .. "/"

          actions.close(prompt_bufnr)

          local keys = string.format(":%s %s", cmd, dir)
          -- Use feedkeys to execute the command so that the command can be modified or extended before running
          vim.api.nvim_feedkeys(keys, "n", true)
        end
      end

      -- Open a file next to the current selection
      local edit_file_next_to_selection = function(prompt_bufnr)
        local action = new_cmd_next_to_selection_action("edit")
        action(prompt_bufnr)
      end

      -- Open a file next to the current selection in a vsplit
      local vsplit_file_next_to_selection = function(prompt_bufnr)
        local action = new_cmd_next_to_selection_action("vsplit")
        action(prompt_bufnr)
      end

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
            mappings = {
              ["i"] = {
                ["<C-o>"] = fb_actions.goto_parent_dir,
              },
            },
          },
          undo = {},
        },
        defaults = require('telescope.themes').get_ivy {
          cache_picker = {
            num_pickers = 10,
          },
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
              ["<C-d>"] = refine_current_dir,
              ["<C-o>"] = refine_parent_dir,
              ["<C-i>"] = refine_previous_dir,
              ["<C-e>"] = edit_file_next_to_selection,
              ["<C-S-e>"] = vsplit_file_next_to_selection,
              ["<esc>"] = actions.close,
              ["<S-esc>"] = function()
                -- exit insert mode
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-[>", true, false, true), "n", true)
              end,
              ["<C-s>"] = actions.cycle_previewers_next,
              ["<C-a>"] = actions.cycle_previewers_prev,
              ["<C-Space>"] = actions.to_fuzzy_refine,
            },
            n = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
            },
          }
        },
        pickers = {
          find_files = {
            find_command = { 'fd', '--type', 'f', '--hidden' },
          },
          buffers = {
            ignore_current_buffer = true,
            sort_mru = true,
          },
        },
      }

      telescope.load_extension('fzf')
      telescope.load_extension('file_browser')
      telescope.load_extension('dap')
      telescope.load_extension('ui-select')
      telescope.load_extension('undo')

      vim.api.nvim_create_user_command('Diagnostics', function() require('telescope.builtin').diagnostics() end, {})
    end,
  },
}
