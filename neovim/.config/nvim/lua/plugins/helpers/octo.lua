local M = {}

-- Mark the current review file as viewed, then jump to the next unviewed one.
--
-- Octo has both halves already (toggle_viewed and select_next_unviewed_file)
-- but no single action combining them, and two things make it more than just
-- calling them back to back:
--
--   * toggle_viewed() toggles, so on a file that is already VIEWED it would
--     unmark it. Only call it when the file still needs marking.
--   * it is async. The GraphQL mutation updates file.viewed_state in a
--     callback, and select_next_unviewed_file() reads that state to decide
--     where to go. Advancing immediately means the current file still looks
--     UNVIEWED and can be picked again, so wait for the state to flip.
--
-- Not implemented as its own mutation so the request and the file panel
-- re-render stay octo's business.

-- How long to wait for the mark-as-viewed mutation before advancing anyway.
local timeout_ms = 5000
local poll_ms = 50

---Advance to the next unviewed file in the current review.
local function select_next_unviewed()
  local layout = require('octo.reviews').get_current_layout()
  if layout then
    layout:select_next_unviewed_file()
  end
end

---Mark the current file as viewed and move to the next unviewed file.
function M.mark_viewed_and_next()
  local layout = require('octo.reviews').get_current_layout()
  if not layout then
    return
  end

  -- get_file_at_cursor() only works from the file panel window, so prefer the
  -- layout's own idea of the current file. That works from the diff windows too.
  local file = layout:get_current_file()
  if not file then
    return
  end

  if file.viewed_state == 'VIEWED' then
    select_next_unviewed()
    return
  end

  file:toggle_viewed()

  -- Poll for the callback to flip viewed_state, rather than advancing right
  -- away, so the file we just marked isn't a candidate for "next unviewed".
  local waited = 0
  local timer = vim.uv.new_timer()
  timer:start(poll_ms, poll_ms, vim.schedule_wrap(function()
    waited = waited + poll_ms
    if file.viewed_state == 'VIEWED' or waited >= timeout_ms then
      timer:stop()
      timer:close()
      if file.viewed_state ~= 'VIEWED' then
        vim.notify('octo: timed out marking ' .. file.path .. ' as viewed', vim.log.levels.WARN)
      end
      select_next_unviewed()
    end
  end))
end

---Register the custom actions on octo's mappings module.
--
-- utils.apply_mappings() resolves an action name against require("octo.mappings"),
-- so a name that isn't defined there is silently skipped. Inject ours before
-- octo builds the review buffers.
function M.register_mappings()
  local mappings = require('octo.mappings')
  mappings.mark_viewed_and_next = M.mark_viewed_and_next
end

return M
