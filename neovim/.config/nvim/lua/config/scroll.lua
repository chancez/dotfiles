-- Wheel scrolling that scales with how fast you are scrolling, and gets out of its own way
-- while you fling.
--
-- Why this exists rather than 'mousescroll': that option is a fixed number of lines per event,
-- so it can be precise or fast but not both. Measured on a 50x200 window in a vertical split,
-- the cost of one wheel event is a whole-window repaint of about 22.5KB regardless of whether
-- it moves 1 line or 15, because a terminal cannot scroll a column range and nvim repaints
-- instead. So lines per event are nearly free and events are what cost. One line while reading,
-- a dozen while flinging.
--
-- Not smooth scrolling. neoscroll and cinnamon interpolate a jump into one repaint per line to
-- make motion look continuous, which is the opposite trade: it spends redraws for smoothness.
-- This spends smoothness for redraws.
--
-- Deliberately does not touch kitty's wheel_scroll_multiplier, which is global and would slow
-- kitty's own scrollback and every other mouse-tracking program to fix nvim.

local M = {}

-- Tuning
--
-- Every option can be changed live, without restarting, which is how the numbers below were
-- arrived at:
--
--     :lua require('config.scroll').opts.curve = 3
--
-- It takes effect on the next wheel event, so you can flip a value mid-scroll and feel the
-- difference in the same buffer.
--
-- Symptom to knob, in the order worth trying:
--
--     accelerates while scrolling slowly     raise curve, then raise burst_ms
--     never accelerates, even flinging       lower curve, or raise fling_gap_ms
--     a fling overshoots                     lower fast_lines
--     reading is too slow, one notch at a    raise slow_lines
--       time barely moves
--     step jumps around unevenly             raise smoothing towards 0.9
--     plugins feel stale after a scroll      lower idle_ms
--
-- The response, measured on this machine with kitty's default wheel_scroll_multiplier of 5.0,
-- as lines moved per physical notch of the wheel:
--
--     notch gap     curve=2 (default)   curve=1   curve=3
--       600ms             5.0             5.0       5.0
--       400ms             5.0             5.0       5.0
--       200ms             5.0             5.0       5.0
--       120ms             5.0             5.0       5.0
--        60ms             5.0             9.2       5.0
--        30ms            14.7            22.5       8.7
--
-- Slow through moderate scrolling is deliberately flat: acceleration should be something you ask
-- for by flinging, not something that creeps in while reading.
M.opts = {
  -- Lines moved per wheel event when scrolling deliberately. The flat part of the table above is
  -- slow_lines multiplied by however many reports your terminal sends per notch, so on kitty at
  -- the default multiplier this is 5 lines per notch, not 1.
  slow_lines = 1,

  -- Ceiling on lines per event, reached only at the fastest scrolling. Bigger covers more ground
  -- per fling at the cost of overshooting what you were aiming at.
  fast_lines = 12,

  -- Milliseconds between notches at which the step is still slow_lines. Shorter gaps scale up
  -- towards fast_lines; anything at or above this stays slow.
  --
  -- Think of it as "how fast counts as fast". Lower means only quick scrolling accelerates.
  fling_gap_ms = 90,

  -- Milliseconds below which two events are treated as the same physical notch rather than as
  -- fast scrolling.
  --
  -- Load-bearing on any terminal that multiplies the wheel, which is most of them. kitty's
  -- wheel_scroll_multiplier defaults to 5.0, so one notch arrives as five mouse reports written
  -- back to back, microseconds apart. Timing raw events therefore measures the terminal's burst
  -- spacing rather than the hand on the wheel. Before this existed, a notch every 600ms, which is
  -- slow deliberate scrolling, moved 37 lines instead of 5.
  --
  -- Raise it if a single notch still accelerates; lower it if very fast scrolling stops
  -- accelerating because whole notches are being swallowed as bursts.
  burst_ms = 25,

  -- Shape of the ramp between slow_lines and fast_lines. 1 is linear. Higher is more gradual at
  -- the slow end, so more of the range stays at slow_lines and it takes genuinely fast scrolling
  -- to accelerate. See the table above for what 1, 2 and 3 do.
  curve = 2,

  -- Fraction of the previous notch-gap estimate to keep, 0 to 1. Stops one irregular notch from
  -- spiking the step, at the cost of the step lagging a change in speed by an event or two.
  -- 0 disables smoothing entirely.
  smoothing = 0.5,

  -- Milliseconds of quiet after the last event before everything is put back: hooks undone,
  -- eventignore restored, the speed estimate reset.
  --
  -- Too high and scroll-reactive plugins stay frozen after you stop. Too low and a slow scroll
  -- keeps tearing the fling setup down and building it up again.
  idle_ms = 150,

  -- Autocmd events suppressed for the duration of a fling. These are what scroll-reactive
  -- plugins hang off, and mid-fling their work is thrown away by the next event anyway. Borrowed
  -- from neoscroll, which does the same around its animations.
  --
  -- Measured over a 15-event fling in a vertical split, interleaved and repeated:
  -- 37317/36631/42056 bytes with it against 56363/56842/43979 without. A single run each first
  -- said the opposite, so if this is ever re-measured, interleave the conditions and repeat them.
  --
  -- Add events here only if a plugin is doing expensive work mid-scroll. Anything that has to
  -- stay correct *during* a scroll, rather than catch up after it, does not belong in this list.
  ignored_events = { 'WinScrolled', 'CursorMoved' },
}

-- Turning treesitter highlighting off during a fling, which is what neoscroll's
-- performance_mode does, was tried and rejected. It makes things worse here: 112897 bytes and
-- 436ms for a fling against 56250 and 217ms with highlighting left alone, because stopping and
-- restarting the parser forces a full re-highlight at both ends of every fling. neoscroll wraps
-- one animation per keypress, so it pays that cost once; this fires per fling.

-- Hooks, in two sets, because the two costs have different thresholds.
--
-- scroll: every wheel event. A float overlapping the window stops nvim scrolling it at all, so
-- anything that has to be out of the way must go on the very first event. Measured: hiding the
-- treesitter-context float took a single notch from 23923 bytes to 1721.
--
-- fling: only once the step has ramped up. Suppressing autocmds for a single notch would make
-- gitsigns and the statusline lag with nothing to show for it.
local hooks = { scroll = {}, unscroll = {}, fling = {}, unfling = {} }

--- Run fn when any scroll starts, and undo after idle_ms of quiet.
---
--- For things that must be out of the way for nvim to scroll at all, which means floating windows
--- overlapping the buffer. Fires on the very first event of even a single notch, so keep fn cheap.
--- Registered in lua/plugins/treesitter.lua to hide the context floats.
---
--- Hooks are called in registration order, wrapped in pcall: one that errors warns and does not
--- stop the others, and does not break scrolling.
---@param fn fun() called on the first event of a scroll
---@param undo fun()|nil called once the scroll has stopped
function M.on_scroll(fn, undo)
  table.insert(hooks.scroll, fn)
  if undo then
    table.insert(hooks.unscroll, undo)
  end
end

--- Run fn when a fling starts, and undo when it ends.
---
--- For work worth avoiding only when there are many events to come, since a single notch does not
--- fire this at all. Used internally for eventignore.
---@param fn fun() called when the step first ramps above slow_lines
---@param undo fun()|nil called once the fling has stopped
function M.on_fling(fn, undo)
  table.insert(hooks.fling, fn)
  if undo then
    table.insert(hooks.unfling, undo)
  end
end

local function run(list)
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn)
    if not ok then
      vim.notify('config.scroll hook failed: ' .. tostring(err), vim.log.levels.WARN)
    end
  end
end

local state = {
  last_ms = 0,
  gap_ms = nil,
  step = 0,
  scrolling = false,
  flinging = false,
  timer = nil,
  saved_eventignore = nil,
}

-- Step from the rate, rather than a counter that ratchets up per consecutive fast event.
--
-- The counter version was the first thing tried and it was too sensitive: any scroll whose gaps
-- sat just under the threshold climbed to fast_lines and stayed there, because nothing ever
-- brought it back down until the scroll stopped entirely. Proportional to the measured gap, a
-- steady moderate scroll sits at a steady moderate step and slowing down slows the step.
local function step_for(gap)
  local o = M.opts
  if gap >= o.fling_gap_ms then
    return o.slow_lines
  end
  local scale = (1 - (gap / o.fling_gap_ms)) ^ o.curve
  local lines = o.slow_lines + (o.fast_lines - o.slow_lines) * scale
  return math.max(o.slow_lines, math.min(o.fast_lines, math.floor(lines + 0.5)))
end

local function start_fling()
  if state.flinging then
    return
  end
  state.flinging = true

  -- Saved and restored whole rather than appended and removed, so a concurrent change to the
  -- option cannot leave our entries behind.
  state.saved_eventignore = vim.o.eventignore
  vim.opt.eventignore:append(M.opts.ignored_events)

  run(hooks.fling)
end

local function stop()
  state.timer = nil
  state.step = 0
  state.gap_ms = nil

  if state.flinging then
    state.flinging = false
    if state.saved_eventignore ~= nil then
      vim.o.eventignore = state.saved_eventignore
      state.saved_eventignore = nil
    end
    run(hooks.unfling)
  end

  if state.scrolling then
    state.scrolling = false
    run(hooks.unscroll)
  end
end

local function scroll(key)
  local now = vim.uv.hrtime() / 1e6
  local gap = now - state.last_ms
  state.last_ms = now

  -- Only gaps between notches feed the estimate. Anything under burst_ms is the terminal
  -- delivering one notch as several reports, and timing those measures the terminal rather than
  -- the hand on the wheel. Events inside a burst reuse the step the last notch gap produced.
  if gap >= M.opts.burst_ms then
    if gap >= M.opts.fling_gap_ms or not state.gap_ms then
      -- A new scroll starts from scratch, so its first notch is always slow_lines.
      --
      -- Seeded with the threshold rather than the real gap, which can be enormous: hrtime() is
      -- nanoseconds since boot and last_ms starts at zero, so the first gap of a session is
      -- around 10^6 ms. Smoothing that raw value never decays below the threshold and
      -- acceleration never engages at all, which measured as a flat 1 line per event.
      state.gap_ms = M.opts.fling_gap_ms
    else
      local keep = M.opts.smoothing
      state.gap_ms = state.gap_ms * keep + gap * (1 - keep)
    end
    state.step = step_for(state.gap_ms)
  elseif state.step == 0 then
    state.step = M.opts.slow_lines
  end

  if not state.scrolling then
    state.scrolling = true
    run(hooks.scroll)
  end
  if state.step > M.opts.slow_lines then
    start_fling()
  end

  -- The wheel acts on the window under the pointer, which need not be the current window, so
  -- the mapping has to route it there itself. nvim's built-in wheel handling does this and a
  -- naive mapping loses it, scrolling the focused window instead.
  local pos = vim.fn.getmousepos()
  local win = (pos and pos.winid and pos.winid ~= 0) and pos.winid
    or vim.api.nvim_get_current_win()
  pcall(vim.fn.win_execute, win, 'normal! ' .. state.step .. key)

  if state.timer then
    state.timer:stop()
  end
  state.timer = vim.defer_fn(stop, M.opts.idle_ms)
end

--- Install the wheel mappings. Call once, from init.lua, before lazy so a plugin's config can
--- register a hook.
---
--- Any option can also be changed after setup by assigning to M.opts, which is read per event.
--- This owns the only mapping of the wheel keys: a second one anywhere else silently wins or
--- loses depending on load order, so register a hook instead of mapping them again.
---@param user_opts table|nil overrides merged over M.opts, see the table above
function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, user_opts or {})

  local modes = { 'n', 'v', 'i' }
  local keys = {
    ['<ScrollWheelDown>'] = vim.keycode('<C-e>'),
    ['<ScrollWheelUp>'] = vim.keycode('<C-y>'),
  }
  for lhs, key in pairs(keys) do
    vim.keymap.set(modes, lhs, function()
      scroll(key)
    end, { desc = 'Scroll, scaled by scroll speed' })
  end
end

return M
