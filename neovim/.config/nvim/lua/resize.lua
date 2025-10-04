local M = {}

local windowing = require('windowing')

local config = {
  vertical_resize_amount = 1,
}

M.ResizeWindow = function(direction, amount, win_id)
  -- Validate amount is a number
  local win = windowing.Window:new(win_id)
  win:resize(direction, amount)
end

local Resizer = {}
Resizer.__index = Resizer

function Resizer:new()
  local instance = setmetatable({}, Resizer)
  return instance
end

function Resizer:start()
  local opts = { noremap = true, silent = true }
  vim.keymap.set('n', '<C-Up>', function() M.ResizeWindow("up", 1) end, opts)
  vim.keymap.set('n', '<C-Down>', function() M.ResizeWindow("down", 1) end, opts)
  vim.keymap.set('n', '<C-Left>', function() M.ResizeWindow("left", 1) end, opts)
  vim.keymap.set('n', '<C-Right>', function() M.ResizeWindow("right", 1) end, opts)
end

M.Resizer = Resizer



return M
