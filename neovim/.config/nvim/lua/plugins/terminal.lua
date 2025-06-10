return {
  {
    'akinsho/toggleterm.nvim',
    opts = {
      open_mapping = '<c-t>',
      start_in_insert = true,
    },
    config = function (_, opts)
      local toggleterm = require("toggleterm")
      toggleterm.setup(opts)

      -- Adapted from https://github.com/akinsho/toggleterm.nvim/blob/9a88eae817ef395952e08650b3283726786fb5fb/lua/toggleterm.lua#L206
      local function sendCurrentBuffer(cmd_data)
        local id = tonumber(cmd_data.args) or 1

        vim.validate({
          terminal_id = { id, "number", true },
        })

        local current_window = vim.api.nvim_get_current_win() -- save current window
        local start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        if not lines or not next(lines) then return end

        for _, line in ipairs(lines) do
          toggleterm.exec(line, id)
        end

        -- Jump back with the cursor where we were at the beginning of the selection
        vim.api.nvim_set_current_win(current_window)
        vim.api.nvim_win_set_cursor(current_window, { start_line, start_col })
      end

      vim.api.nvim_create_user_command('ToggleTermSendCurrentBuffer', sendCurrentBuffer, { bang = true })
    end
  },
}
