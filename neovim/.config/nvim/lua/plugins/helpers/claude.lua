local M = {}

-- Extract a display-friendly summary from a Claude Code session JSONL entry.
-- Session lines have top-level keys: type, message, timestamp, toolUseResult, etc.
-- message.content is either a string or array of {type, text} / {type, tool_use_id} blocks.
local function session_display_text(json)
  -- For user/assistant messages, extract the first text block
  if json.message and json.message.content then
    local content = json.message.content
    if type(content) == "string" then
      return (json.type or "unknown") .. ": " .. content
    end
    if type(content) == "table" then
      for _, block in ipairs(content) do
        if type(block) == "table" and block.text then
          return (json.type or "unknown") .. ": " .. block.text
        end
      end
      -- tool_use blocks (assistant requesting a tool)
      for _, block in ipairs(content) do
        if type(block) == "table" and block.type == "tool_use" then
          return "tool_use: " .. (block.name or "unknown")
        end
      end
    end
  end
  -- Lines with toolUseResult at the top level (tool output records)
  if json.toolUseResult then
    local tr = json.toolUseResult
    if tr.filePath then
      return "tool_result: " .. tr.filePath
    end
    return "tool_result: " .. vim.inspect(tr):gsub("\n", " "):sub(1, 200)
  end
  -- queue-operation, summary, etc.
  if json.type then
    return json.type
  end
  return nil
end

-- Build formatted preview lines from a parsed Claude Code session JSONL entry.
local function session_preview_lines(entry, json)
  local lines = {}

  table.insert(lines, "# Type: " .. (json.type or "unknown"))
  if json.message and json.message.role then
    table.insert(lines, "# Role: " .. json.message.role)
  end
  table.insert(lines, "# Session: " .. entry.value.session_id)
  table.insert(lines, "# File: " .. entry.value.file)
  if json.timestamp then
    table.insert(lines, "# Time: " .. json.timestamp)
  end
  if json.cwd then
    table.insert(lines, "# CWD: " .. json.cwd)
  end
  table.insert(lines, "")

  -- Show message content
  if json.message and json.message.content then
    local content = json.message.content
    if type(content) == "string" then
      vim.list_extend(lines, vim.split(content, "\n"))
    elseif type(content) == "table" then
      for _, block in ipairs(content) do
        if type(block) == "table" then
          if block.text then
            vim.list_extend(lines, vim.split(block.text, "\n"))
            table.insert(lines, "")
          elseif block.type == "tool_use" then
            table.insert(lines, "---")
            table.insert(lines, "**Tool: " .. (block.name or "unknown") .. "**")
            if block.input then
              vim.list_extend(lines, vim.split(vim.inspect(block.input), "\n"))
            end
            table.insert(lines, "")
          elseif block.type == "tool_result" then
            table.insert(lines, "---")
            table.insert(lines, "**Tool Result** (tool_use_id: " .. (block.tool_use_id or "") .. ")")
            table.insert(lines, "")
          end
        end
      end
    end
  end

  -- Show top-level toolUseResult (the actual tool output data)
  if json.toolUseResult then
    table.insert(lines, "---")
    table.insert(lines, "## Tool Use Result")
    table.insert(lines, "")
    vim.list_extend(lines, vim.split(vim.inspect(json.toolUseResult), "\n"))
  end

  return lines
end

-- Open a telescope picker that searches Claude session .jsonl files by content
-- and restores the selected session via agentic.
local function telescope_search_claude_sessions()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local session_directory = vim.fn.expand("~/.claude/projects/")

  pickers.new({}, {
    prompt_title = "Search Claude Sessions",
    finder = finders.new_async_job({
      command_generator = function(prompt)
        if not prompt or prompt == "" then
          return nil
        end
        return {
          "rg", "--no-heading", "--line-number", "--color=never",
          "--glob", "!*subagents*",
          "--glob", "*.jsonl",
          "--sortr", "modified",
          "-i",
          "--", prompt, session_directory,
        }
      end,
      entry_maker = function(line)
        -- rg output: file:line_number:matched_text
        -- Use non-greedy (.-) so we split on the first :digits: separator,
        -- not a :digits: pattern inside the JSON text.
        local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
        if not file then
          return nil
        end
        local ok, json = pcall(vim.json.decode, text)
        -- Only show user prompts and assistant replies, skip tool results and metadata
        if not ok or not json or (json.type ~= "user" and json.type ~= "assistant") then
          return nil
        end
        -- Skip meta/system messages (command outputs, tool results, etc.)
        if json.isMeta then
          return nil
        end
        if json.message and json.message.content and type(json.message.content) == "table" then
          local first = json.message.content[1]
          if first and type(first) == "table" and (first.type == "tool_result" or first.type == "tool_use") then
            return nil
          end
        end
        local session_id = vim.fn.fnamemodify(file, ":t:r")
        local session_cwd = json.cwd or ""
        local editor_cwd = vim.fn.getcwd()
        -- Shorten session cwd: omit if same as editor cwd, show relative if
        -- within editor cwd, otherwise show absolute path.
        local display_cwd
        if session_cwd == editor_cwd or session_cwd == "" then
          display_cwd = nil
        elseif session_cwd:sub(1, #editor_cwd + 1) == editor_cwd .. "/" then
          display_cwd = session_cwd:sub(#editor_cwd + 2)
        else
          display_cwd = session_cwd
        end
        local display_text = session_display_text(json) or text
        display_text = display_text:gsub("\n", " "):sub(1, 200)
        local display
        if display_cwd then
          display = string.format("[%s] %s: %s", display_cwd, session_id:sub(1, 8), display_text)
        else
          display = string.format("%s: %s", session_id:sub(1, 8), display_text)
        end
        return {
          value = { file = file, lnum = tonumber(lnum), text = text, session_id = session_id, cwd = session_cwd, timestamp = json.timestamp or "" },
          display = display,
          ordinal = display_text,
        }
      end,
    }),
    -- Custom sorter: rg handles text matching, so all entries already match.
    -- Score purely by timestamp — newer entries get lower scores (ranked higher).
    -- Telescope: lower score = ranked higher, 0 = filtered out.
    sorter = require("telescope.sorters").Sorter:new({
      scoring_function = function(_self, _prompt, _line, entry)
        if not entry or not entry.value or not entry.value.timestamp then
          return 1
        end
        -- Parse YYYYMMDDHHmmss from ISO 8601 (ignore millis to fit float64
        -- integer precision of ~15 digits). Already in chronological order,
        -- so larger = newer. Subtract so newer → lower score → ranked higher.
        -- Can't negate because telescope filters out scores <= 0.
        local y, mo, d, h, mi, s = entry.value.timestamp:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)")
        local ts_num = tonumber(y .. mo .. d .. h .. mi .. s) or 0
        return 1e15 - ts_num
      end,
    }),
    previewer = previewers.new_buffer_previewer({
      title = "Session Line",
      define_preview = function(self, entry, _status)
        local text = entry.value.text
        local ok, json = pcall(vim.json.decode, text)
        local lines
        if ok and json then
          lines = session_preview_lines(entry, json)
        else
          lines = vim.split(text, "\n")
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = "markdown"
      end,
    }),
    attach_mappings = function(prompt_bufnr, _map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          -- Defer to main loop — telescope's close callback runs in a fast
          -- event context where nvim API calls are not allowed.
          vim.defer_fn(function()
            require("agentic").restore_session_by_id(selection.value.session_id)
          end, 0)
        end
      end)
      return true
    end,
  }):find()
end

M.telescope_search_claude_sessions = telescope_search_claude_sessions

return M
