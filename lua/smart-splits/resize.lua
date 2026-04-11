local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local mux = lazy.require_on_exported_call('smart-splits.mux') --[[@as SmartSplitsMuxApi]]
local win = require('smart-splits.win')
local types = require('smart-splits.types')
local Direction = types.Direction

local WinPosition = win.WinPosition
local DirectionKeys = win.DirectionKeys
local WincmdResizeDirection = win.WincmdResizeDirection

local M = {}

M.is_resizing = false

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_vertical(direction)
  local current_pos = win.win_position(direction)
  if current_pos == WinPosition.start or current_pos == WinPosition.middle then
    return direction == Direction.down and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  end
  return direction == Direction.down and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
end

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_horizontal(direction)
  local at_left = win.at_left_edge()
  local at_right = win.at_right_edge()
  local current_pos
  if at_left then
    current_pos = WinPosition.start
  elseif at_right then
    current_pos = WinPosition.last
  else
    current_pos = WinPosition.middle
  end
  local result
  if current_pos == WinPosition.start or current_pos == WinPosition.middle then
    result = direction == Direction.right and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  else
    result = direction == Direction.right and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
  end
  -- special case - check if there is an ignored window to the left
  if direction == Direction.right and result == WincmdResizeDirection.bigger and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    win.next_window(DirectionKeys.left, true, M.is_resizing)
    if
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    then
      vim.api.nvim_set_current_win(cur_win)
      result = WincmdResizeDirection.smaller
    end
  elseif direction == Direction.left and result == WincmdResizeDirection.smaller and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    win.next_window(DirectionKeys.left, true, M.is_resizing)
    if
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    then
      vim.api.nvim_set_current_win(cur_win)
      result = WincmdResizeDirection.bigger
    end
  end

  return result
end

---@param direction SmartSplitsDirection
---@param amount number
function M.resize(direction, amount)
  amount = amount or config.default_amount

  if win.handle_floating_window(function()
    mux.resize_pane(direction, amount)
  end) then
    return
  end

  -- if a full width window and horizontal resize check if we can resize with multiplexer
  if
    (direction == Direction.left or direction == Direction.right)
    and win.is_full_width()
    and mux.resize_pane(direction, amount)
  then
    return
  end

  -- if a full height window and vertical resize check if we can resize with multiplexer
  if
    (direction == Direction.down or direction == Direction.up)
    and win.is_full_height()
    and (mux.resize_pane(direction, amount) or mux.get() ~= nil)
  then
    return
  end

  if direction == Direction.down or direction == Direction.up then
    -- vertically
    local plus_minus = compute_direction_vertical(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('resize %s%s', plus_minus, amount))
    if win.win_position(direction) ~= WinPosition.middle then
      return
    end

    local new_win_pos = vim.api.nvim_win_get_position(0)
    local adjustment_plus_minus
    if cur_win_pos[1] < new_win_pos[1] and plus_minus == WincmdResizeDirection.smaller then
      adjustment_plus_minus = WincmdResizeDirection.bigger
    elseif cur_win_pos[1] > new_win_pos[1] and plus_minus == WincmdResizeDirection.bigger then
      adjustment_plus_minus = WincmdResizeDirection.smaller
    end

    if win.at_bottom_edge() then
      if plus_minus == WincmdResizeDirection.bigger then
        vim.cmd(string.format('resize -%s', amount))
        win.next_window(DirectionKeys.down, false, M.is_resizing)
        vim.cmd(string.format('resize -%s', amount))
      else
        vim.cmd(string.format('resize +%s', amount))
        win.next_window(DirectionKeys.down, false, M.is_resizing)
        vim.cmd(string.format('resize +%s', amount))
      end
      return
    end

    if adjustment_plus_minus ~= nil then
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      win.next_window(DirectionKeys.up, false, M.is_resizing)
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      win.next_window(DirectionKeys.down, false, M.is_resizing)
    end
  else
    -- horizontally
    local plus_minus = compute_direction_horizontal(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('vertical resize %s%s', plus_minus, amount))
    if win.win_position(direction) ~= WinPosition.middle then
      return
    end

    local new_win_pos = vim.api.nvim_win_get_position(0)
    local adjustment_plus_minus
    if cur_win_pos[2] < new_win_pos[2] and plus_minus == WincmdResizeDirection.smaller then
      adjustment_plus_minus = WincmdResizeDirection.bigger
    elseif cur_win_pos[2] > new_win_pos[2] and plus_minus == WincmdResizeDirection.bigger then
      adjustment_plus_minus = WincmdResizeDirection.smaller
    end
    if adjustment_plus_minus ~= nil then
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      win.next_window(DirectionKeys.right, false, M.is_resizing)
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      win.next_window(DirectionKeys.left, false, M.is_resizing)
    end
  end
end

return M
