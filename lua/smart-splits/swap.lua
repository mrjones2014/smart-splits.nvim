local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local win = require('smart-splits.win')
local types = require('smart-splits.types')
local Direction = types.Direction

local DirectionKeys = win.DirectionKeys
local DirectionKeysReverse = win.DirectionKeysReverse

local M = {}

---@param direction SmartSplitsDirection
---@param opts table
function M.swap_bufs(direction, opts)
  opts = opts or {}

  if win.handle_floating_window() then
    return
  end

  local buf_1 = vim.api.nvim_get_current_buf()
  local win_1 = vim.api.nvim_get_current_win()
  local win_view_1 = vim.fn.winsaveview()

  local dir_key = DirectionKeys[direction]
  local will_wrap = (direction == Direction.right and win.at_right_edge())
    or (direction == Direction.left and win.at_left_edge())
    or (direction == Direction.up and win.at_top_edge())
    or (direction == Direction.down and win.at_bottom_edge())
  if will_wrap then
    dir_key = DirectionKeysReverse[direction]
  end

  win.next_win_or_wrap(will_wrap, dir_key)
  local buf_2 = vim.api.nvim_get_current_buf()
  local win_2 = vim.api.nvim_get_current_win()
  local win_view_2 = vim.fn.winsaveview()

  -- special case, same buffer in both windows, just swap cursor/scroll position
  if buf_1 == buf_2 then
    local win_1_folds_enabled = vim.api.nvim_get_option_value('foldenable', { win = win_1 })
    local win_2_folds_enabled = vim.api.nvim_get_option_value('foldenable', { win = win_2 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_1 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_2 })

    vim.api.nvim_set_current_win(win_1)
    vim.fn.winrestview(win_view_2)
    vim.api.nvim_set_current_win(win_2)
    vim.fn.winrestview(win_view_1)

    vim.api.nvim_set_option_value('foldenable', win_1_folds_enabled, { win = win_1 })
    vim.api.nvim_set_option_value('foldenable', win_2_folds_enabled, { win = win_2 })
  else
    vim.api.nvim_win_set_buf(win_2, buf_1)
    vim.api.nvim_win_set_buf(win_1, buf_2)
  end

  local move_cursor_with_buf = opts.move_cursor
  if move_cursor_with_buf == nil then
    move_cursor_with_buf = config.cursor_follows_swapped_bufs
  end
  if move_cursor_with_buf then
    vim.api.nvim_set_current_win(win_2)
  else
    vim.api.nvim_set_current_win(win_1)
  end
end

return M
