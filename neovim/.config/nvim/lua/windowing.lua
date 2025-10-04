local M = {}

-- TODO: Figure out statusline height dynamically
local status_line_height = 1
-- TODO: Figure out statuscolumn width dynamically
local status_column_width = 1

-- Returns true if a is between b and c (inclusive)
-- @param val The value to check
-- @param lower The lower bound
-- @param upper The upper bound
local function within(val, lower, upper)
  return val >= lower and val <= upper
end

-- @class Window
-- @field id The window id
local Window = {}
Window.__index = Window

function Window:new(id)
  local instance = setmetatable({}, Window)
  instance.id = id or vim.api.nvim_get_current_win()
  return instance
end

function Window:__tostring()
  return string.format("Window(id=%d)", self.id)
end

function Window:top()
  return vim.api.nvim_win_get_position(self.id)[1]
end

function Window:bottom()
  return self:top() + self:height()
end

function Window:left()
  return vim.api.nvim_win_get_position(self.id)[2]
end

function Window:right()
  return self:left() + self:width()
end

function Window:height()
  return vim.api.nvim_win_get_height(self.id)
end

function Window:width()
  return vim.api.nvim_win_get_width(self.id)
end

function Window:top_touches(other)
  return (other:bottom() + status_line_height) == self:top()
end

function Window:bottom_touches(other)
  return other:top() == (self:bottom() + status_line_height)
end

function Window:left_touches(other)
  return other:right() == (self:left() - status_column_width)
end

function Window:right_touches(other)
  return (other:left() - status_column_width) == self:right()
end

function Window:horizontal_sides_within(other)
  return within(self:left(), other:left(), other:right()) or
      within(self:right(), other:left(), other:right())
end

function Window:vertical_sides_within(other)
  return within(self:top(), other:top(), other:bottom()) or
      within(self:bottom(), other:top(), other:bottom())
end

function Window:is_above(other)
  return self:bottom_touches(other) and (self:horizontal_sides_within(other) or other:horizontal_sides_within(self))
end

function Window:is_below(other)
  return self:top_touches(other) and (self:horizontal_sides_within(other) or other:horizontal_sides_within(self))
end

function Window:is_left_of(other)
  return self:right_touches(other) and (self:vertical_sides_within(other) or other:vertical_sides_within(self))
end

function Window:is_right_of(other)
  return self:left_touches(other) and (self:vertical_sides_within(other) or other:vertical_sides_within(self))
end

function Window:neighbors()
  local neighbors = {
    left = {},
    right = {},
    up = {},
    down = {},
  }

  local wins = vim.api.nvim_list_wins()

  -- Collect all non-floating windows except the current one
  for _, other_id in ipairs(wins) do
    local other_conf = vim.api.nvim_win_get_config(other_id)
    -- Filter out floating windows (relative is not empty for floats)
    if other_id ~= self.id and other_conf.relative == "" then
      local other = Window:new(other_id)

      -- Check if the other window is directly above
      if other:is_above(self) then
        table.insert(neighbors.up, other)
      end

      -- check if the other window is directly below
      if other:is_below(self) then
        table.insert(neighbors.down, other)
      end

      -- Check if the other window is directly to the left
      if other:is_left_of(self) then
        table.insert(neighbors.left, other)
      end

      -- Check if the other window is directly to the right
      if other:is_right_of(self) then
        table.insert(neighbors.right, other)
      end
    end
  end

  return neighbors
end

local direction_to_letter = {
  left  = "h",
  right = "l",
  above = "k",
  up    = "k",
  below = "j",
  down  = "j",
}

function Window:neighbor(direction)
  local letter = direction_to_letter[direction]
  if not letter then
    error(string.format("Invalid direction '%s'. Valid directions are: %s", direction,
      table.concat(vim.tbl_keys(direction_to_letter), ", ")))
  end
  local neighbor_nr = vim.fn.winnr(letter)
  -- check if it's a popup
  if neighbor_nr == 0 then
    return false
  end
  -- Check if it's ourself
  local id = vim.fn.win_getid(neighbor_nr)
  if id == self.id then
    return false
  end
  local neighbor = Window:new(id)
  return neighbor
end

function Window:resize_up(amount)
  amount = amount or 1
  -- Decrease the size of the window above us
  local neighbor = self:neighbor("above")
  if neighbor then
    neighbor:resize_down(-amount)
  end
end

function Window:resize_down(amount)
  amount = amount or 1
  -- Only resize in a direction if it's possible
  -- If we don't have a neighbor to below us, we can't grow "down".
  -- Doing so would result in growing "up".
  if amount > 0 then
    local neighbor = self:neighbor("below")
    if not neighbor then
      return
    end
  end
  vim.api.nvim_win_set_height(self.id, self:height() + amount)
end

function Window:resize_right(amount)
  amount = amount or 1
  -- Only resize in a direction if it's possible
  -- If we don't have a neighbor to our right, we can't grow "right".
  -- Doing so would result in growing to the "left".
  if amount > 0 then
    local neighbor = self:neighbor("right")
    if not neighbor then
      return
    end
  end
  vim.api.nvim_win_set_width(self.id, self:width() + amount)
end

function Window:resize_left(amount)
  amount = amount or 1
  -- Decrease the size of the window to our left
  local neighbor = self:neighbor("left")
  if neighbor then
    neighbor:resize_right(-amount)
  end
end

function Window:resize(direction, amount)
  vim.validate {
    direction = { direction, 'string' },
    amount = { amount, 'number' }
  }
  amount = amount or 1
  local f = self["resize_" .. direction]
  if not f then
    error(string.format("Invalid direction '%s'. Valid directions are: up, down, left, right", direction))
  end
  f(self, amount)
end

M.Window = Window

return M
