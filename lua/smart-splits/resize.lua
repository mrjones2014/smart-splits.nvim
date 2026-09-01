local Types = require('smart-splits.types')
local Win = require('smart-splits.win')
local Direction = Types.Direction
local WinPosition = Win.WinPosition
local DirectionKeys = Win.DirectionKeys
local WincmdResizeDirection = Win.WincmdResizeDirection

local M = {}

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_vertical(direction)
  local pos = Win.win_position(direction)
  if pos == WinPosition.start or pos == WinPosition.middle then
    return direction == Direction.down and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  end
  return direction == Direction.down and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
end

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_horizontal(direction)
  local at_left = Win.at_left_edge()
  local at_right = Win.at_right_edge()

  local pos
  if at_left then
    pos = WinPosition.start
  elseif at_right then
    pos = WinPosition.last
  else
    pos = WinPosition.middle
  end

  local result
  if pos == WinPosition.start or pos == WinPosition.middle then
    result = direction == Direction.right and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  else
    result = direction == Direction.right and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
  end

  -- spanning the full width usually means growing, but not when the only thing
  -- to the left is a window we ignore, like a file tree
  if at_left and at_right then
    local buftypes, filetypes = require('smart-splits.config').ignores('resize')
    local flip = (direction == Direction.right and result == WincmdResizeDirection.bigger)
      or (direction == Direction.left and result == WincmdResizeDirection.smaller)
    if flip then
      local cur_win = vim.api.nvim_get_current_win()
      Win.next_window(DirectionKeys.left, true, true)
      if Win.is_ignored(nil, buftypes, filetypes) then
        vim.api.nvim_set_current_win(cur_win)
        result = direction == Direction.right and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
      else
        vim.api.nvim_set_current_win(cur_win)
      end
    end
  end

  return result
end

---@param direction SmartSplitsDirection
---@param amount number
local function resize_vertical(direction, amount)
  local plus_minus = compute_direction_vertical(direction)
  local cur_win_pos = vim.api.nvim_win_get_position(0)
  vim.cmd(('resize %s%s'):format(plus_minus, amount))
  if Win.win_position(direction) ~= WinPosition.middle then
    return
  end

  local new_win_pos = vim.api.nvim_win_get_position(0)
  local adjustment
  if cur_win_pos[1] < new_win_pos[1] and plus_minus == WincmdResizeDirection.smaller then
    adjustment = WincmdResizeDirection.bigger
  elseif cur_win_pos[1] > new_win_pos[1] and plus_minus == WincmdResizeDirection.bigger then
    adjustment = WincmdResizeDirection.smaller
  end

  if Win.at_bottom_edge() then
    local sign = plus_minus == WincmdResizeDirection.bigger and '-' or '+'
    vim.cmd(('resize %s%s'):format(sign, amount))
    Win.next_window(DirectionKeys.down, false, true)
    vim.cmd(('resize %s%s'):format(sign, amount))
    return
  end

  if adjustment ~= nil then
    vim.cmd(('resize %s%s'):format(adjustment, amount))
    Win.next_window(DirectionKeys.up, false, true)
    vim.cmd(('resize %s%s'):format(adjustment, amount))
    Win.next_window(DirectionKeys.down, false, true)
  end
end

---@param direction SmartSplitsDirection
---@param amount number
local function resize_horizontal(direction, amount)
  local plus_minus = compute_direction_horizontal(direction)
  local cur_win_pos = vim.api.nvim_win_get_position(0)
  vim.cmd(('vertical resize %s%s'):format(plus_minus, amount))
  if Win.win_position(direction) ~= WinPosition.middle then
    return
  end

  local new_win_pos = vim.api.nvim_win_get_position(0)
  local adjustment
  if cur_win_pos[2] < new_win_pos[2] and plus_minus == WincmdResizeDirection.smaller then
    adjustment = WincmdResizeDirection.bigger
  elseif cur_win_pos[2] > new_win_pos[2] and plus_minus == WincmdResizeDirection.bigger then
    adjustment = WincmdResizeDirection.smaller
  end

  if adjustment ~= nil then
    vim.cmd(('vertical resize %s%s'):format(adjustment, amount))
    Win.next_window(DirectionKeys.right, false, true)
    vim.cmd(('vertical resize %s%s'):format(adjustment, amount))
    Win.next_window(DirectionKeys.left, false, true)
  end
end

---@param direction SmartSplitsDirection
---@param amount number|nil defaults to `v:count1 * config.resize.amount`
function M.resize(direction, amount)
  amount = amount or (vim.v.count1 * require('smart-splits.config').resize.amount)

  if Win.handle_floating_window() then
    return
  end

  local horizontal = direction == Direction.left or direction == Direction.right
  local fills_axis = horizontal and Win.is_full_width() or (not horizontal and Win.is_full_height())

  if fills_axis then
    -- the multiplexer is the only thing that can grow this window, and nvim must
    -- not try: it shrinks a window that fills the axis into `cmdheight` with no
    -- way to get the space back, see
    -- https://github.com/mrjones2014/smart-splits.nvim/issues/336
    require('smart-splits.backend').resize(direction, amount)
    return
  end

  if horizontal then
    resize_horizontal(direction, amount)
  else
    resize_vertical(direction, amount)
  end
end

---Run a resize with the configured events suppressed, restoring the focused
---window afterwards.
---@param direction SmartSplitsDirection
---@param amount number|nil
function M.run(direction, amount)
  local eventignore = Win.set_eventignore()
  local cur_win = vim.api.nvim_get_current_win()

  local ok, err = pcall(M.resize, direction, amount)
  if not ok then
    require('smart-splits.log').error('failed to resize %s: %s', direction, err)
  end

  pcall(vim.api.nvim_set_current_win, cur_win)
  -- luacheck:ignore
  vim.o.eventignore = eventignore
end

return M
