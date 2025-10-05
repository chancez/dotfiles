local M = {}

local window = require('window')

local default_config = {
  vertical_resize_amount = 1,
  horizontal_resize_amount = 1,
  relative_resizing = false,
  mappings = {
    up = 'k',
    down = 'j',
    left = 'h',
    right = 'l',
    stop_resizing = '<Esc>',
  },
}

-- a helper function to set a keymap and return the current mapping
local function map(mode, lhs, rhs, opts)
  -- Get the current global keymap
  -- TODO: Figure out buffer mappings which takes predence over global mappings
  local current_map = vim.fn.maparg(lhs, mode, false, true)
  -- Set the new keymap
  vim.keymap.set(mode, lhs, rhs, opts)
  return current_map
end

M.resize = function(direction, amount, win_id)
  local win = window.new(win_id)
  win:resize(direction, amount)
end

M.relative_resize = function(direction, amount, win_id)
  local win = window.new(win_id)
  win:relative_resize(direction, amount)
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

  local opts = { silent = true }

  local resize_func = M.resize
  if self.cfg.relative_resizing then
    resize_func = M.relative_resize
  end
  local resize_mappings = {
    -- Positive mappings
    { key = self.cfg.mappings.up,            dir = "up",                       amount = self.cfg.vertical_resize_amount,    func = resize_func },
    { key = self.cfg.mappings.down,          dir = "down",                     amount = self.cfg.vertical_resize_amount,    func = resize_func },
    { key = self.cfg.mappings.left,          dir = "left",                     amount = self.cfg.horizontal_resize_amount,  func = resize_func },
    { key = self.cfg.mappings.right,         dir = "right",                    amount = self.cfg.horizontal_resize_amount,  func = resize_func },
    -- negative mappings
    { key = self.cfg.mappings.up:upper(),    dir = "up",                       amount = -self.cfg.vertical_resize_amount,   func = resize_func },
    { key = self.cfg.mappings.down:upper(),  dir = "down",                     amount = -self.cfg.vertical_resize_amount,   func = resize_func },
    { key = self.cfg.mappings.left:upper(),  dir = "left",                     amount = -self.cfg.horizontal_resize_amount, func = resize_func },
    { key = self.cfg.mappings.right:upper(), dir = "right",                    amount = -self.cfg.horizontal_resize_amount, func = resize_func },
    { key = self.cfg.mappings.stop_resizing, func = function() self:stop() end },
  }

  local it = vim.iter(resize_mappings)
  it:map(function(mapping)
    return {
      lhs = mapping.key,
      -- map returns the existing mapping so we can restore it later
      old = map('n', mapping.key, function()
        mapping.func(mapping.dir, mapping.amount)
      end, opts),
    }
  end)
  it:totable()

  self.current_mappings = it
end

function Resizer:stop()
  -- restore old mappings
  for mapping in self.current_mappings do
    if next(mapping.old) ~= nil then
      vim.fn.mapset(mapping.old)
    else
      -- Mapping was empty so delete the new temporary mapping
      vim.keymap.del('n', mapping.lhs)
    end
  end
  self.current_mappings = {}
  self.active = false
end

M.Resizer = Resizer

return M
