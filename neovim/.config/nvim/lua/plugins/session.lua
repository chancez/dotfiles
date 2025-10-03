return {
  {
    'rmagatti/auto-session',
    branch = 'feat/pre-restore-override',
    lazy = false,
    ---enables autocomplete for opts
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { '~/', '~/projects', '~/Downloads', '/' },
      session_lens = {
        load_on_setup = false,
        picker = "telescope",
        picker_opts = {
          theme = 'ivy',
        },
      },
      -- log_level = 'debug',
      git_auto_restore_on_branch_change = true,
      git_use_branch_name = function(path)
        local lib = require("auto-session.lib")
        local cmd = string.format('git-current-branch %s', path or "")
        lib.logger.debug("git_get_branch_name: executing " .. cmd)
        local out = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          lib.logger.debug("git_get_branch_name: git failed with: " .. out)
          return nil
        end
        lib.logger.debug("git_get_branch_name: got branch: " .. out)
        return vim.fn.trim(out)
      end,
      no_restore_cmds = {
        -- If there is no existing session, clear out all buffers
        function(is_startup)
          if (is_startup) then
            return
          end
          vim.ui.input({ prompt = 'No restore: clear all buffers? ([y]/n): ' }, function(input)
            if input == 'n' then
              return
            end
            local lib = require("auto-session.lib")
            lib.logger.debug("no_restore: clearing all buffers")
            lib.conditional_buffer_wipeout(false)
          end)
        end
      },
    },
  },
}
