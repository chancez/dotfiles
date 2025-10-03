return {
  {
    'akinsho/toggleterm.nvim',
    opts = {
      open_mapping = '<c-t>',
      start_in_insert = true,
    },
    lazy = false,
    keys = {
      '<c-t>',
      { '<leader>sb', ':ToggleTermSendCurrentBuffer<CR>',          desc = 'Send current buffer to terminal',                         mode = { 'n' } },
      { '<leader>sB', ':ToggleTermSendCurrentBufferSemiColon<CR>', desc = 'Send current buffer to terminal followed by a semicolon', mode = { 'n' } },
      { '<leader>sv', ':ToggleTermSendVisualSelection<CR>',        desc = 'Send visual selection to terminal',                       mode = { 'v' } },
      { '<leader>su', ':ToggleTermClearInput<CR>',                 desc = 'Clear input in the terminal (C-u)',                       mode = { 'n' } },
    },
    config = function(_, opts)
      local toggleterm = require("toggleterm")
      toggleterm.setup(opts)

      -- Send ctrl-u to the terminal to clear current input
      local function clearInput(cmd_data)
        cmd_data = cmd_data or {}
        local id = tonumber(cmd_data.args) or 1

        vim.validate({
          terminal_id = { id, "number", true },
        })

        toggleterm.exec(vim.api.nvim_replace_termcodes("<C-u>", true, false, true), id)
      end

      -- Adapted from https://github.com/akinsho/toggleterm.nvim/blob/9a88eae817ef395952e08650b3283726786fb5fb/lua/toggleterm.lua#L206
      local function sendCurrentBuffer(cmd_data)
        cmd_data = cmd_data or {}
        local id = tonumber(cmd_data.args) or 1

        vim.validate({
          terminal_id = { id, "number", true },
        })

        clearInput(cmd_data)

        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        if not lines or not next(lines) then return end

        for _, line in ipairs(lines) do
          toggleterm.exec(line, id)
        end
      end

      vim.api.nvim_create_user_command('ToggleTermSendCurrentBuffer', sendCurrentBuffer, { bang = true })
      -- A hack to make ClickHouse CLI process SQL statements sent to it. It doesn't process the semicolon
      -- If everything is sent together so we have to add a delay before sending the semi colon.
      -- TODO: Maybe we can use bracket paste within the terminal?
      vim.api.nvim_create_user_command('ToggleTermSendCurrentBufferSemiColon', function()
        sendCurrentBuffer()
        -- sleep before sending the semicolon to ensure the previous command has been processed
        vim.defer_fn(function()
          toggleterm.exec(";")
        end, 1000)
      end, { bang = true })
      vim.api.nvim_create_user_command('ToggleTermClearInput', clearInput, { bang = true })
    end
  },
}
