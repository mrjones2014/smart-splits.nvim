local Types = require('smart-splits.types')
local Win = require('smart-splits.win')
local Direction = Types.Direction
local AtEdgeBehavior = Types.AtEdgeBehavior
local DirectionKeys = Win.DirectionKeys
local DirectionKeysReverse = Win.DirectionKeysReverse

---Per-call options for `move_cursor_*`.
---@class SmartSplitsMoveOpts
---@field same_row boolean|nil override `config.move.same_row`
---@field at_edge SmartSplitsAtEdgeBehavior|nil override `config.move.at_edge`

---Passed to `config.move.at_edge` when it is a function.
---@class SmartSplitsAtEdgeContext
---@field backend SmartSplitsBackend|nil the resolved backend, `nil` if none resolved
---@field direction SmartSplitsDirection direction you tried to move, so also the edge you are sitting on
---@field split fun() split the current window towards `direction`
---@field wrap fun() jump to the window on the opposite edge

local M = {}

---Put the cursor back on the screen row it started on.
---@param offset number
local function restore_row(offset)
  vim.cmd('normal! ' .. (offset - vim.api.nvim_win_get_position(0)[1]) .. 'H')
end

---@param direction SmartSplitsDirection
local function at_edge_split(direction)
  local buftypes, filetypes = require('smart-splits.config').ignores('move')
  if Win.is_ignored(nil, buftypes, filetypes) then
    return
  end

  if require('smart-splits.backend').split(direction, {}) then
    return
  end
  Win.split(direction)
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsMoveOpts|nil
function M.move_cursor(direction, opts)
  local Config = require('smart-splits.config')
  opts = type(opts) == 'table' and opts or {}
  local same_row = opts.same_row
  if same_row == nil then
    same_row = Config.move.same_row
  end
  local at_edge = opts.at_edge or Config.move.at_edge

  -- the backend cannot see `at_edge`, and a multiplexer that wraps around its own
  -- edges would otherwise wrap even for someone who asked to stop
  ---@type SmartSplitsBackendMoveOpts
  local move_opts = { wrap = at_edge == AtEdgeBehavior.wrap }

  local Backend = require('smart-splits.backend')
  local dir_key = DirectionKeys[direction]
  local horizontal = direction == Direction.left or direction == Direction.right
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]

  -- sidebar style floats sit alongside real splits, so move out of them like any
  -- other window, and hand off to the multiplexer once against the screen edge
  if Win.is_embedded_float() then
    if Win.is_float_at_screen_edge(direction) then
      Backend.move(direction, move_opts)
      return
    end
    vim.cmd('wincmd ' .. dir_key)
    if horizontal and same_row then
      restore_row(offset)
    end
    return
  end

  if Win.handle_floating_window() then
    return
  end

  -- `winnr('h')` returns the current window when there is nothing to the left, so
  -- this equality means an nvim move would not go anywhere
  local win_to_move_to = vim.fn.winnr(vim.v.count1 .. dir_key)
  local win_before = vim.v.count1 == 1 and vim.fn.winnr() or vim.fn.winnr(vim.v.count1 - 1 .. dir_key)
  local at_nvim_edge = win_to_move_to == win_before

  if at_nvim_edge then
    if Backend.move(direction, move_opts) then
      return
    end

    if type(at_edge) == 'function' then
      at_edge({
        backend = Backend.resolve(),
        direction = direction,
        split = function()
          Win.split(direction)
        end,
        wrap = function()
          Win.next_win_or_wrap(true, DirectionKeysReverse[direction])
        end,
      })
      return
    elseif at_edge == AtEdgeBehavior.stop then
      return
    elseif at_edge == AtEdgeBehavior.split then
      at_edge_split(direction)
      return
    end

    -- wrapping with a count would skip past windows, so only wrap without one
    if vim.v.count1 == 1 then
      dir_key = DirectionKeysReverse[direction]
    end
  end

  Win.next_win_or_wrap(at_nvim_edge, dir_key)

  if horizontal and same_row then
    restore_row(offset)
  end
end

return M
