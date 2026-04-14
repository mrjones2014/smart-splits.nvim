local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local mux = lazy.require_on_exported_call('smart-splits.mux') --[[@as SmartSplitsMuxApi]]
local utils = require('smart-splits.utils')
local win = require('smart-splits.win')
local types = require('smart-splits.types')
local Direction = types.Direction
local AtEdgeBehavior = types.AtEdgeBehavior

local DirectionKeys = win.DirectionKeys
local DirectionKeysReverse = win.DirectionKeysReverse

---@param direction SmartSplitsDirection
local function split_edge(direction)
  if direction == Direction.left or direction == Direction.right then
    vim.cmd('vsp')
    if vim.opt.splitright and direction == Direction.left then
      vim.cmd('wincmd h')
    end
  else
    vim.cmd('sp')
    if vim.opt.splitbelow and direction == Direction.up then
      vim.cmd('wincmd k')
    end
  end
end

local M = {}

---@param direction SmartSplitsDirection
---@param opts table
function M.move_cursor(direction, opts)
  local same_row = config.move_cursor_same_row
  local at_edge = config.at_edge
  if type(opts) == 'table' then
    if opts.same_row ~= nil then
      same_row = opts.same_row
    end
    if opts.at_edge ~= nil then
      at_edge = opts.at_edge
    end
  end

  local dir_key = DirectionKeys[direction]
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]

  if utils.is_embedded_floating_window() then
    if utils.is_floating_window_at_screen_edge(nil, direction) then
      mux.move_pane(direction, true, at_edge)
      return
    end
    vim.cmd('wincmd ' .. dir_key)
    if (direction == Direction.left or direction == Direction.right) and same_row then
      offset = offset - vim.api.nvim_win_get_position(0)[1]
      vim.cmd('normal! ' .. offset .. 'H')
    end
    return
  end
  if win.handle_floating_window(function()
    mux.move_pane(direction, true, at_edge)
  end) then
    return
  end

  -- are we at an edge and attempting to move in the direction of the edge we're already at?
  local win_to_move_to = vim.fn.winnr(vim.v.count1 .. dir_key)
  local win_before = vim.v.count1 == 1 and vim.fn.winnr() or vim.fn.winnr(vim.v.count1 - 1 .. dir_key)
  local will_wrap = win_to_move_to == win_before

  if will_wrap then
    -- if we can move with mux, then we're good
    if mux.move_pane(direction, will_wrap, at_edge) then
      return
    end

    -- otherwise check at_edge behavior
    if type(at_edge) == 'function' then
      local ctx = { ---@type SmartSplitsContext
        mux = mux.get(),
        direction = direction,
        split = function()
          split_edge(direction)
        end,
        wrap = function()
          win.next_win_or_wrap(will_wrap, DirectionKeysReverse[direction])
        end,
      }
      at_edge(ctx)
      return
    elseif at_edge == AtEdgeBehavior.stop then
      return
    elseif at_edge == AtEdgeBehavior.split then
      -- if at_edge = 'split' and we're in an ignored buffer, just stop
      if
        vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
        or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
      then
        return
      end

      local did_split = mux.split_pane(direction)
      if not did_split then
        split_edge(direction)
      end
      return
    else -- at_edge == AtEdgeBehavior.wrap
      -- shouldn't wrap if count is > 1
      if vim.v.count1 == 1 then
        dir_key = DirectionKeysReverse[direction]
      end
    end
  end

  win.next_win_or_wrap(will_wrap, dir_key)

  if (direction == Direction.left or direction == Direction.right) and same_row then
    offset = offset - vim.api.nvim_win_get_position(0)[1]
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

return M
