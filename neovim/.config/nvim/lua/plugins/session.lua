local SessionPIDFile = {}

function SessionPIDFile:new(session_name)
  local lib = require("auto-session.lib")
  self.session_name = session_name
  self.state_dir = vim.fn.stdpath('data') .. '/active_sessions/'
  self.state_file_path = self.state_dir .. lib.escape_session_name(session_name) .. ".pid"
  self.logger = lib.logger
  return self
end

function SessionPIDFile:write_pid(pid)
  -- Create the directory if needed
  vim.fn.mkdir(self.state_dir, 'p')
  -- Open the file and store the pid
  local file, err_msg = io.open(self.state_file_path, 'w')
  if not file then
    return nil, err_msg
  end
  file:write(tostring(pid))
  file:close()
  return true
end

function SessionPIDFile:read_pid()
  local file = io.open(self.state_file_path, 'r')
  if not file then
    return nil, "Failed to open state file for reading"
  end
  local pid = file:read()
  file:close()
  return tonumber(pid)
end

function SessionPIDFile:delete()
  os.remove(self.state_file_path)
end

function SessionPIDFile:exists()
  local file = io.open(self.state_file_path, 'r')
  if file then
    file:close()
    return true
  end
  return false
end

function SessionPIDFile:get_path()
  return self.state_file_path
end

return {
  {
    'rmagatti/auto-session',
    lazy = false,
    ---enables autocomplete for opts
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { '~/', '~/projects', '~/Downloads', '/', '/tmp', '/private/tmp' },
      close_filetypes_on_save = { "neotest-output", "neotest-output-panel", "neotest-summary" },
      session_lens = {
        load_on_setup = false,
        picker = "telescope",
        picker_opts = {
          theme = 'ivy',
        },
      },
      -- log_level = 'debug',
      -- git_use_branch_name = true,
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
          if not vim.g.auto_session_enabled then
            return
          end
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
      post_restore_cmds = {
        -- Track the PID of the current neovim instance so we can avoid
        -- restoring the session when it's already 'open'.
        function(session_name)
          local pid = vim.fn.getpid()
          local state = SessionPIDFile:new(session_name)
          local lib = require("auto-session.lib")

          -- Store the pid in a file
          local ok, err_msg = state:write_pid(pid)
          if not ok then
            lib.logger.error(string.format("post_restore: failed creating session state: %s", err_msg))
            return
          end

          lib.logger.debug(string.format("post_restore: wrote pid %d to %s", pid, state:get_path()))

          -- Setup a hook to delete the pid file when vim closes
          vim.api.nvim_create_autocmd("VimLeavePre", {
            callback = function()
              state:delete()
              lib.logger.debug("post_restore: removed pid file for session ", session_name)
            end
          })
        end
      },
      pre_restore_cmds = {
        -- Check if there is an existing neovim instance with this session open
        function(session_name)
          local lib = require("auto-session.lib")
          local state = SessionPIDFile:new(session_name)
          local pid = state:read_pid()
          if pid then
            local state_file_path = state:get_path()
            -- check if the pid still exists and is an nvim using pgrep and check the exit code
            local cmd = { "pgrep", "-F", state_file_path, "nvim" }
            lib.logger.debug("pre_restore: executing ", cmd)
            local ret = vim.system(cmd):wait()
            if ret.code ~= 0 then
              -- nvim with the pid is not running so this is a left over PID we should clean up
              lib.logger.debug(string.format("pre_restore: removing stale session pid file: %s", state_file_path))
              state:delete()
              return true
            end

            -- Track that a session exists in a vim global so that we can avoid
            -- overwriting it when the current vim instance closes
            vim.g.auto_session_existing_session_name = session_name
            lib.logger.debug(string.format("pre_restore: found existing session pid file: %s, pid: %d", state_file_path,
              pid))
            vim.notify(
              string.format("Not restoring session %s because it is already open in another neovim instance (PID %d)",
                session_name, pid),
              vim.log.levels.INFO, { title = "auto-session" }
            )
            return false
          end
        end
      },
      pre_save_cmds = {
        -- When vim opened, we checked if an existing session was open. Check
        -- that again before saving to avoid overwriting an existing session
        -- that was closed while vim instance was open.
        function(session_name)
          if vim.g.auto_session_existing_session_name == session_name then
            local lib = require("auto-session.lib")
            lib.logger.debug(string.format(
              "pre_save: not saving session %s because it was already open in another neovim instance", session_name))
            vim.notify(
              string.format("Not saving session %s because it was already open in another neovim instance", session_name),
              vim.log.levels.WARN, { title = "auto-session" }
            )
            return false
          end
        end
      },
    },
  },
}
