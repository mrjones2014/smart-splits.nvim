local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local mux = lazy.require_on_exported_call('smart-splits.mux') --[[@as SmartSplitsMuxApi]]
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local mux_utils = require('smart-splits.mux.utils')
local win = require('smart-splits.win')
local resize_mod = require('smart-splits.resize')
local move_mod = require('smart-splits.move')
local swap_mod = require('smart-splits.swap')
local types = require('smart-splits.types')
local Direction = types.Direction

local M = {}

---@param direction SmartSplitsDirection
---@return WinPosition
function M.win_position(direction)
  return win.win_position(direction)
end

vim.tbl_map(function(direction)
  M[string.format('resize_%s', direction)] = function(amount)
    local eventignore_orig = vim.o.eventignore
    win.set_eventignore()
    local cur_win_id = vim.api.nvim_get_current_win()
    resize_mod.is_resizing = true
    amount = amount or (vim.v.count1 * config.default_amount)
    local ok, error = pcall(resize_mod.resize, direction, amount)
    if not ok then
      log.error('failed to resize: %s', error)
    end
    pcall(vim.api.nvim_set_current_win, cur_win_id)
    resize_mod.is_resizing = false
    -- luacheck:ignore
    vim.o.eventignore = eventignore_orig
  end
  M[string.format('move_cursor_%s', direction)] = function(opts)
    resize_mod.is_resizing = false
    local ok, error = pcall(move_mod.move_cursor, direction, opts)
    if not ok then
      log.error('failed to move cursor: %s', error)
    end
  end
  M[string.format('swap_buf_%s', direction)] = function(opts)
    resize_mod.is_resizing = false
    local ok, error = pcall(swap_mod.swap_bufs, direction, opts)
    if not ok then
      log.error('failed to swap buffers: %s', error)
    end
  end
end, {
  Direction.left,
  Direction.right,
  Direction.up,
  Direction.down,
})

function M.move_cursor_previous()
  local prev_win = mux_utils.get_previous_win()
  if prev_win and vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
end

function M.update_layout_details()
  mux.update_layout_details()
end

return M
