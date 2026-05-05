-- Lookup the "nice" name for the model from config options.
-- Eg: "us.anthropic.claude-opus-4-6-v1" -> "Opus"
local function update_model_from_config(tab_page_id, config_options)
  for _, opt in ipairs(config_options) do
    if opt.category == "model" then
      local model_name = opt.currentValue
      for _, option in ipairs(opt.options or {}) do
        if option.value == opt.currentValue then
          model_name = option.name
          break
        end
      end
      vim.t[tab_page_id].agentic_model = model_name
    end
  end
end

local function jump_to_prompt(amount)
  -- Define the prefix to match lines that indicate user prompts in the AgenticChat buffer.
  local prefix = '##.* User'
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Collect all matching line numbers
  local matches = {}
  for i, line in ipairs(lines) do
    if vim.fn.match(line, prefix) >= 0 then
      table.insert(matches, i)
    end
  end

  if #matches == 0 then
    return
  end

  -- Find the target based on direction and count
  -- Compare against landing position (match + 2) to avoid re-matching current prompt
  local offset = 2
  local target
  if amount > 0 then
    local idx = 0
    for i, row in ipairs(matches) do
      if row + offset > cursor_row then
        idx = i
        break
      end
    end
    if idx > 0 then
      target = matches[math.min(idx + amount - 1, #matches)]
    end
  else
    local idx = 0
    for i, row in ipairs(matches) do
      if row + offset < cursor_row then
        idx = i
      end
    end
    if idx > 0 then
      target = matches[math.max(idx + amount + 1, 1)]
    end
  end

  if target then
    -- Set a mark before jumping to support jumping back to previous location.
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(0, { target + 2, 0 })
  end
end

return {
  {
    'zbirenbaum/copilot.lua',
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      -- disable suggestions and panel since we're using cmp
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        yaml = true,
        gitcommit = true,
        markdown = true,
      },
      copilot_node_command = { "mise", "exec", "node@lts", "--", "node", "--use-system-ca" },
      server = {
        type = 'nodejs',
        custom_server_filepath = vim.fn.stdpath("data") .. "/mason/bin/copilot-language-server",
      },
      server_opts_overrides = {
        settings = {
          advanced = {
            listCount = 10,         -- #completions for panel
            inlineSuggestCount = 3, -- #completions for getCompletions
            length = 300,           -- max length of copilot suggestions
          }
        },
      },
      -- Override should_attach to allow copilot in AgenticInput buffers
      -- AgenticInput uses buftype = "nofile" which copilot.lua rejects by default
      should_attach = function(bufnr, bufname)
        local filetype = vim.bo[bufnr].filetype

        if filetype == "AgenticInput" then
          return true
        end

        -- Delegate to default behavior for all other buffers
        local default_should_attach =
            require("copilot.config.should_attach").default
        return default_should_attach(bufnr, bufname)
      end,
    }
  },
  {
    "carlos-algms/agentic.nvim",
    opts = {
      -- provider = "codex-acp",
      provider = "claude-agent-acp",
      acp_providers = {
        ["claude-agent-acp"] = {
          default_mode = "acceptEdits",
        },
      },

      windows = {
        width = "33%",
      },

      hooks = {
        on_create_session_response = function(data)
          -- Clear the existing usage data when a new session gets created.
          vim.t[data.tab_page_id].agentic_usage = nil

          if data.response and data.response.configOptions then
            update_model_from_config(data.tab_page_id, data.response.configOptions)
          end

          local SessionRegistry = require("agentic.session_registry")
          SessionRegistry.get_session_for_tab_page(data.tab_page_id, function(session)
            session:schedule_header_refresh()
          end)
        end,

        -- TODO: need hooks for session/set_config_option and session/set_model
        -- so we can reset the model when it's changed mid session.

        on_session_update = function(data)
          local needs_refresh = false
          if data.update.sessionUpdate == "usage_update" then
            vim.t[data.tab_page_id].agentic_usage = data.update
            needs_refresh = true
          end
          if data.update.sessionUpdate == "config_option_update" then
            update_model_from_config(data.tab_page_id, data.update.configOptions)
            needs_refresh = true
          end

          if not needs_refresh then
            return
          end

          local SessionRegistry = require("agentic.session_registry")
          SessionRegistry.get_session_for_tab_page(data.tab_page_id, function(session)
            session:schedule_header_refresh()
          end)
        end,
      },

      headers = {
        chat = function(parts)
          local pieces = { parts.title }
          if parts.context ~= nil then
            table.insert(pieces, parts.context)
          end
          if parts.suffix ~= nil then
            table.insert(pieces, parts.suffix)
          end

          local model = vim.t.agentic_model
          if model ~= nil then
            table.insert(pieces, "Model: " .. model)
          end

          local usage = vim.t.agentic_usage
          if usage ~= nil then
            local used = tonumber(usage.used) or 0
            local size = tonumber(usage.size) or 0
            if size > 0 then
              local pct = (used / size) * 100
              table.insert(pieces, ("Context: %.1f%%%% (%d/%d)"):format(pct, used, size))
              if usage.cost ~= nil then
                table.insert(pieces, ("%.2f %s"):format(usage.cost.amount, usage.cost.currency))
              end
            end
          end

          return table.concat(pieces, " | ")
        end,
      },
    },

    config = function(_, opts)
      require("agentic").setup(opts)
      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'AgenticInput',
        callback = function(ev)
          -- Defer the setting to ensure it runs after the plugin's setup
          vim.schedule(function()
            vim.b[ev.buf].completion = true
          end)
        end,
      })
      -- Set the AgenticChat buffer syntax to markdown for better formatting
      vim.api.nvim_create_autocmd({ 'FileType' }, {
        pattern = 'AgenticChat',
        callback = function(ev)
          vim.bo[ev.buf].syntax = "markdown"
        end,
      })
    end,
    keys = {
      {
        "<leader>ac",
        function() require("agentic").toggle({ auto_add_to_context = false }) end,
        mode = { "n", "v", "i" },
        desc = "Toggle Agentic Chat"
      },
      {
        "<leader>af",
        function() require("agentic").add_selection_or_file_to_context({ focus_prompt = false }) end,
        mode = { "n", "v" },
        desc = "Add file or selection to Agentic to Context"
      },
      {
        "<leader>aF",
        function()
          local agentic = require("agentic")
          -- Get the currently visible buffers based on the windows in the current tab
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            -- Check the buffer is valid and loaded and not an agentic buffer
            local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not ft:match("^Agentic") then
              table.insert(bufs, buf)
            end
          end
          agentic.add_files_to_context({ files = bufs, focus_prompt = false })
        end,
        mode = { "n", "v" },
        desc = "Add visible buffers to Agentic Context"
      },
      {
        "<leader>aq",
        function()
          local agentic = require("agentic")
          -- Get the quickfix list items
          local qflist = vim.fn.getqflist()
          -- Track unique buffer numbers to avoid duplicates
          local seen_bufs = {}
          local bufs = {}
          for _, item in ipairs(qflist) do
            if item.bufnr and item.bufnr > 0 and not seen_bufs[item.bufnr] then
              seen_bufs[item.bufnr] = true
              -- Check the buffer is valid and loaded
              if vim.api.nvim_buf_is_valid(item.bufnr) then
                table.insert(bufs, item.bufnr)
              end
            end
          end
          agentic.add_files_to_context({ files = bufs, focus_prompt = false })
        end,
        mode = { "n", "v" },
        desc = "Add files from quickfix list to Agentic Context"
      },
      {
        "<leader>aD",
        function() require("agentic").add_buffer_diagnostics() end,
        mode = { "n", "v" },
        desc = "Add buffer diagnostics to Agentic to Context"
      },
      {
        "<leader>ad",
        function() require("agentic").add_current_line_diagnostics() end,
        mode = { "n", "v" },
        desc = "Add diagnostics to Agentic to Context"
      },
      {
        "<leader>an",
        function() require("agentic").new_session({ auto_add_to_context = false }) end,
        mode = { "n", "v", "i" },
        desc = "New Agentic Session"
      },
      {
        "<leader>as",
        function() require("agentic").stop_generation() end,
        mode = { "n", "v", "i" },
        desc = "Stop current generation"
      },
      {
        "<leader>ar",
        function() require("agentic").restore_session() end,
        mode = { "n", "v" },
        desc = "Show session picker to restore a previous session and continue"
      },
      {
        "<leader>aR",
        function() require("plugins.helpers.claude").telescope_search_claude_sessions() end,
        mode = { "n", "v" },
        desc = "Search and restore a Claude session by content"
      },
      {
        "]p",
        function() jump_to_prompt(vim.v.count1) end,
        mode = { "n", "v" },
        desc = "Jump to next prompt",
        ft = 'AgenticChat',
      },
      {
        "[p",
        function() jump_to_prompt(-vim.v.count1) end,
        mode = { "n", "v" },
        desc = "Jump to previous prompt",
        ft = 'AgenticChat',
      },
    },
  }
}
