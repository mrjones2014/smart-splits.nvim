local Types = require('smart-splits.types')
local Win = require('smart-splits.win')
local Direction = Types.Direction
local DirectionKeys = Win.DirectionKeys
local DirectionKeysReverse = Win.DirectionKeysReverse

---Per-call options for `swap_buf_*`.
---@class SmartSplitsSwapOpts
---@field move_cursor boolean|nil override `config.swap.move_cursor`

local M = {}

---@param direction SmartSplitsDirection
---@param opts SmartSplitsSwapOpts|nil
function M.swap_bufs(direction, opts)
  opts = type(opts) == 'table' and opts or {}

  if Win.handle_floating_window() then
    return
  end

  local buf_1 = vim.api.nvim_get_current_buf()
  local win_1 = vim.api.nvim_get_current_win()
  local view_1 = vim.fn.winsaveview()

  local dir_key = DirectionKeys[direction]
  local at_edge = (direction == Direction.right and Win.at_right_edge())
    or (direction == Direction.left and Win.at_left_edge())
    or (direction == Direction.up and Win.at_top_edge())
    or (direction == Direction.down and Win.at_bottom_edge())
  if at_edge then
    dir_key = DirectionKeysReverse[direction]
  end

  Win.next_win_or_wrap(at_edge, dir_key)
  local buf_2 = vim.api.nvim_get_current_buf()
  local win_2 = vim.api.nvim_get_current_win()
  local view_2 = vim.fn.winsaveview()

  if buf_1 == buf_2 then
    -- same buffer in both windows, so there is nothing to swap but the cursor and
    -- scroll position; folds have to come off first or restoring the view moves
    -- the cursor somewhere else
    local folds_1 = vim.api.nvim_get_option_value('foldenable', { win = win_1 })
    local folds_2 = vim.api.nvim_get_option_value('foldenable', { win = win_2 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_1 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_2 })

    vim.api.nvim_set_current_win(win_1)
    vim.fn.winrestview(view_2)
    vim.api.nvim_set_current_win(win_2)
    vim.fn.winrestview(view_1)

    vim.api.nvim_set_option_value('foldenable', folds_1, { win = win_1 })
    vim.api.nvim_set_option_value('foldenable', folds_2, { win = win_2 })
  else
    vim.api.nvim_win_set_buf(win_2, buf_1)
    vim.api.nvim_win_set_buf(win_1, buf_2)
  end

  local move_cursor = opts.move_cursor
  if move_cursor == nil then
    move_cursor = require('smart-splits.config').swap.move_cursor
  end
  vim.api.nvim_set_current_win(move_cursor and win_2 or win_1)
end

return M
