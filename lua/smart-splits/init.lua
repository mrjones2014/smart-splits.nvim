local lazy = require('smart-splits.lazy')
local Direction = require('smart-splits.types').Direction

---@class SmartSplits
---@field resize_left fun(): nil
---@field resize_right fun(): nil
---@field resize_up fun(): nil
---@field resize_down fun(): nil
---@field move_cursor_left fun(): nil
---@field move_cursor_right fun(): nil
---@field move_cursor_up fun(): nil
---@field move_cursor_down fun(): nil
---@field swap_buf_left fun(): nil
---@field swap_buf_right fun(): nil
---@field swap_buf_up fun(): nil
---@field swap_buf_down fun(): nil
---@field move_cursor_previous fun(): nil
---@field setup fun(config: SmartSplitsConfig): nil

local M = {}

function M.setup(config)
  require('smart-splits.config').setup(config)
end

vim.tbl_map(function(direction)
  local resize_key = string.format('resize_%s', direction)
  local move_key = string.format('move_cursor_%s', direction)
  local swap_buf_key = string.format('swap_buf_%s', direction)
  M[resize_key] = lazy.require_on_exported_call('smart-splits.api')[resize_key]
  M[move_key] = lazy.require_on_exported_call('smart-splits.api')[move_key]
  M[swap_buf_key] = lazy.require_on_exported_call('smart-splits.api')[swap_buf_key]
end, {
  Direction.left,
  Direction.right,
  Direction.up,
  Direction.down,
})

M.move_cursor_previous = lazy.require_on_exported_call('smart-splits.api').move_cursor_previous

---@cast M SmartSplits
return M
