local M = {}

local windowing = require('windowing')

local default_config = {
  vertical_resize_amount = 1,
  horizontal_resize_amount = 1,
  relative_resizing = false,
}

-- a helper function to set a keymap and return the current mapping
local function map(mode, lhs, rhs, opts)
  -- Get the current keymap
  local current_map = vim.fn.maparg(lhs, mode, false, true)
  -- Set the new keymap
  vim.keymap.set(mode, lhs, rhs, opts)
  return current_map
end

M.ResizeWindow = function(direction, amount, win_id)
  -- Validate amount is a number
  local win = windowing.Window:new(win_id)
  win:resize(direction, amount)
end

M.ResizeWindowRelative = function(direction, amount, win_id)
  -- Validate amount is a number
  local win = windowing.Window:new(win_id)
  win:resize_relative(direction, amount)
end

local Resizer = {}
Resizer.__index = Resizer

function Resizer:new(cfg)
  local instance = setmetatable({}, Resizer)
  instance.active = false
  instance.current_mappings = {}
  instance.cfg = vim.tbl_deep_extend('force', default_config, cfg)
  return instance
end

function Resizer:start()
  if self.active then
    return
  end
  self.active = true

  local opts = { noremap = true, silent = true }
  -- Store current mappings and set new ones
  -- Track the lhs because map() returns an empty table if there is no existing mapping.

  if not self.cfg.relative_resizing then
    -- Absolute resizing
    self.current_mappings = {
      -- Positive resizing
      k = map('n', 'k', function() M.ResizeWindow("up", self.cfg.vertical_resize_amount) end, opts),
      j = map('n', 'j', function() M.ResizeWindow("down", self.cfg.vertical_resize_amount) end, opts),
      h = map('n', 'h', function() M.ResizeWindow("left", self.cfg.horizontal_resize_amount) end, opts),
      l = map('n', 'l', function() M.ResizeWindow("right", self.cfg.horizontal_resize_amount) end, opts),
      -- Negative resizing
      K = map('n', 'K', function() M.ResizeWindow("up", -self.cfg.vertical_resize_amount) end, opts),
      J = map('n', 'J', function() M.ResizeWindow("down", -self.cfg.vertical_resize_amount) end, opts),
      H = map('n', 'H', function() M.ResizeWindow("left", -self.cfg.horizontal_resize_amount) end, opts),
      L = map('n', 'L', function() M.ResizeWindow("right", -self.cfg.horizontal_resize_amount) end, opts),
      -- Stop resizing
      ['<Esc>'] = map('n', '<Esc>', function() self:stop() end, opts),
    }
  else
    self.current_mappings = {
      -- Relative resizing
      k = map('n', 'k', function() M.ResizeWindowRelative("up", self.cfg.vertical_resize_amount) end, opts),
      j = map('n', 'j', function() M.ResizeWindowRelative("down", self.cfg.vertical_resize_amount) end, opts),
      h = map('n', 'h', function() M.ResizeWindowRelative("left", self.cfg.horizontal_resize_amount) end, opts),
      l = map('n', 'l', function() M.ResizeWindowRelative("right", self.cfg.horizontal_resize_amount) end, opts),
      -- Stop resizing
      ['<Esc>'] = map('n', '<Esc>', function() self:stop() end, opts),
    }
  end
end

function Resizer:stop()
  -- restore old mappings
  for lhs, mapping in pairs(self.current_mappings) do
    if next(mapping) ~= nil then
      vim.fn.mapset(mapping)
    else
      -- Mapping was empty so delete the new temporary mapping
      vim.keymap.del('n', lhs)
    end
  end
  self.current_mappings = {}
  self.active = false
end

M.Resizer = Resizer

return M
