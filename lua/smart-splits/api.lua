local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local mux = lazy.require_on_exported_call('smart-splits.mux') --[[@as SmartSplitsMuxApi]]
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local utils = require('smart-splits.utils')
local mux_utils = require('smart-splits.mux.utils')
local types = require('smart-splits.types')
local Direction = types.Direction
local AtEdgeBehavior = types.AtEdgeBehavior
local FloatWinBehavior = types.FloatWinBehavior

local M = {}

---@enum WinPosition
local WinPosition = {
  start = 0,
  middle = 1,
  last = 2,
}

---@enum DirectionKeys
local DirectionKeys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

---@enum DirectionKeysReverse
local DirectionKeysReverse = {
  left = 'l',
  right = 'h',
  up = 'j',
  down = 'k',
}

---@enum WincmdResizeDirection
local WincmdResizeDirection = {
  bigger = '+',
  smaller = '-',
}

local is_resizing = false

---@param winnr number|nil window ID, defaults to current window
---@return boolean
local function is_full_height(winnr)
  -- for vertical height account for tabline, status line, and cmd line
  local window_height = vim.o.lines - vim.o.cmdheight
  if (vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1) or vim.o.laststatus > 1 then
    window_height = window_height - 1
  end
  if (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) or vim.o.showtabline == 2 then
    window_height = window_height - 1
  end
  return vim.api.nvim_win_get_height(winnr or 0) == window_height
end

---@param winnr number|nil window ID, defaults to current window
---@return boolean
local function is_full_width(winnr)
  return vim.api.nvim_win_get_width(winnr or 0) == vim.o.columns
end

---@param direction DirectionKeys
---@param skip_ignore_lists boolean|nil defaults to false
local function next_window(direction, skip_ignore_lists)
  local cur_win = vim.api.nvim_get_current_win()
  if direction == DirectionKeys.down or direction == DirectionKeys.up then
    vim.cmd('wincmd ' .. direction)
    if
      not skip_ignore_lists
      and is_resizing
      and (
        vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
        or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
      )
    then
      vim.api.nvim_set_current_win(cur_win)
    end
    return
  end

  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  vim.cmd('wincmd ' .. direction)
  if
    not skip_ignore_lists
    and is_resizing
    and (
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    )
  then
    vim.api.nvim_set_current_win(cur_win)
    return nil
  end
  local view = vim.fn.winsaveview()
  offset = offset - vim.api.nvim_win_get_position(0)[1]
  vim.cmd('normal! ' .. offset .. 'H')
  return view
end

---@return boolean
local function at_top_edge()
  return vim.fn.winnr() == vim.fn.winnr('k')
end

---@return boolean
local function at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

---@return boolean
local function at_left_edge()
  return vim.fn.winnr() == vim.fn.winnr('h')
end

---@return boolean
local function at_right_edge()
  return vim.fn.winnr() == vim.fn.winnr('l')
end

---@param direction SmartSplitsDirection
---@return WinPosition
function M.win_position(direction)
  if direction == Direction.left or direction == Direction.right then
    if at_left_edge() then
      return WinPosition.start
    end

    if at_right_edge() then
      return WinPosition.last
    end

    return WinPosition.middle
  end

  if at_top_edge() then
    return WinPosition.start
  end

  if at_bottom_edge() then
    return WinPosition.last
  end

  return WinPosition.middle
end

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_vertical(direction)
  local current_pos = M.win_position(direction)
  if current_pos == WinPosition.start or current_pos == WinPosition.middle then
    return direction == Direction.down and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  end

  return direction == Direction.down and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
end

---@param direction SmartSplitsDirection
---@return WincmdResizeDirection
local function compute_direction_horizontal(direction)
  local current_pos = M.win_position(direction)
  local result
  if current_pos == WinPosition.start or current_pos == WinPosition.middle then
    result = direction == Direction.right and WincmdResizeDirection.bigger or WincmdResizeDirection.smaller
  else
    result = direction == Direction.right and WincmdResizeDirection.smaller or WincmdResizeDirection.bigger
  end

  local at_left = at_left_edge()
  local at_right = at_right_edge()
  -- special case - check if there is an ignored window to the left
  if direction == Direction.right and result == WincmdResizeDirection.bigger and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    next_window(DirectionKeys.left, true)
    if
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    then
      vim.api.nvim_set_current_win(cur_win)
      result = WincmdResizeDirection.smaller
    end
  elseif direction == Direction.left and result == WincmdResizeDirection.smaller and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    next_window(DirectionKeys.left, true)
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

---@param mux_callback fun()|nil
---@return boolean
local function handle_floating_window(mux_callback)
  if utils.is_floating_window() then
    if config.float_win_behavior == FloatWinBehavior.previous then
      -- focus the last accessed window.
      -- if it's also floating, do not attempt to perform the action.
      local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
      if utils.is_floating_window(prev_win) then
        return true
      end

      vim.api.nvim_set_current_win(prev_win)
      return false
    elseif config.float_win_behavior == FloatWinBehavior.mux then
      -- always forward the action to the multiplexer
      if mux_callback then
        mux_callback()
      end
      return true
    end
  end
  return false
end

---@param direction SmartSplitsDirection
---@param amount number
local function resize(direction, amount)
  amount = amount or config.default_amount

  if handle_floating_window(function()
    mux.resize_pane(direction, amount)
  end) then
    return
  end

  -- if a full width window and horizontall resize check if we can resize with multiplexer
  if
    (direction == Direction.left or direction == Direction.right)
    and is_full_width()
    and mux.resize_pane(direction, amount)
  then
    return
  end

  -- if a full height window and vertical resize check if we can resize with multiplexer
  if
    (direction == Direction.down or direction == Direction.up)
    and is_full_height()
    -- if not using a multiplexer, trying to vertically resize
    -- a full height window can result in the nvim window being
    -- permanently stuck with empty space below the status bar
    and (mux.resize_pane(direction, amount) or mux.get() ~= nil)
  then
    return
  end

  if direction == Direction.down or direction == Direction.up then
    -- vertically
    local plus_minus = compute_direction_vertical(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('resize %s%s', plus_minus, amount))
    if M.win_position(direction) ~= WinPosition.middle then
      return
    end

    local new_win_pos = vim.api.nvim_win_get_position(0)
    local adjustment_plus_minus
    if cur_win_pos[1] < new_win_pos[1] and plus_minus == WincmdResizeDirection.smaller then
      adjustment_plus_minus = WincmdResizeDirection.bigger
    elseif cur_win_pos[1] > new_win_pos[1] and plus_minus == WincmdResizeDirection.bigger then
      adjustment_plus_minus = WincmdResizeDirection.smaller
    end

    if at_bottom_edge() then
      if plus_minus == WincmdResizeDirection.bigger then
        vim.cmd(string.format('resize -%s', amount))
        next_window(DirectionKeys.down)
        vim.cmd(string.format('resize -%s', amount))
      else
        vim.cmd(string.format('resize +%s', amount))
        next_window(DirectionKeys.down)
        vim.cmd(string.format('resize +%s', amount))
      end
      return
    end

    if adjustment_plus_minus ~= nil then
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      next_window(DirectionKeys.up)
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      next_window(DirectionKeys.down)
    end
  else
    -- horizontally
    local plus_minus = compute_direction_horizontal(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('vertical resize %s%s', plus_minus, amount))
    if M.win_position(direction) ~= WinPosition.middle then
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
      next_window(DirectionKeys.right)
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      next_window(DirectionKeys.left)
    end
  end
end

---@param will_wrap boolean
---@param dir_key DirectionKeys
local function next_win_or_wrap(will_wrap, dir_key)
  -- if someone has more than 99999 windows then just LOL
  vim.api.nvim_set_current_win(
    vim.fn.win_getid(vim.fn.winnr(string.format('%s%s', will_wrap and '99999' or vim.v.count1, dir_key)))
  )
end

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

---@param direction SmartSplitsDirection
---@param opts table
local function move_cursor(direction, opts)
  -- backwards compatibility, if opts is a boolean, treat it as historical `same_row` argument
  local same_row = config.move_cursor_same_row
  local at_edge = config.at_edge
  if type(opts) == 'boolean' then
    same_row = opts
    vim.deprecate(
      string.format('smartsplits.move_cursor_%s(boolean)', direction),
      string.format("smartsplits.move_cursor_%s({ same_row = boolean, at_edge = 'wrap'|'split'|'stop' })", direction),
      'smart-splits.nvim'
    )
  elseif type(opts) == 'table' then
    if opts.same_row ~= nil then
      same_row = opts.same_row
    end

    if opts.at_edge ~= nil then
      at_edge = opts.at_edge
    end
  end

  if handle_floating_window(function()
    mux.move_pane(direction, true, at_edge)
  end) then
    return
  end

  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  local dir_key = DirectionKeys[direction]

  -- are we at an edge and attempting to move in the direction of the edge we're already at?
  local win_to_move_to = vim.fn.winnr(vim.v.count1 .. dir_key)
  local win_before = vim.v.count1 == 1 and vim.fn.winnr() or vim.fn.winnr(vim.v.count1 - 1 .. dir_key)
  -- fn.winnr will return the same number for any move beyond border
  -- if it is the same as the one one move closer - move is beyond
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
          next_win_or_wrap(will_wrap, DirectionKeysReverse[direction])
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

  next_win_or_wrap(will_wrap, dir_key)

  if (direction == Direction.left or direction == Direction.right) and same_row then
    offset = offset - vim.api.nvim_win_get_position(0)[1]
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

local function set_eventignore()
  local eventignore = vim.o.eventignore
  if #eventignore > 0 and not vim.endswith(eventignore, ',') then
    eventignore = eventignore .. ','
  end
  eventignore = eventignore .. table.concat(config.ignored_events or {}, ',')
  -- luacheck:ignore
  vim.o.eventignore = eventignore
end

---@param direction SmartSplitsDirection
---@param opts table
local function swap_bufs(direction, opts)
  opts = opts or {}

  if handle_floating_window() then
    return
  end

  local buf_1 = vim.api.nvim_get_current_buf()
  local win_1 = vim.api.nvim_get_current_win()
  local win_view_1 = vim.fn.winsaveview()

  local dir_key = DirectionKeys[direction]
  local will_wrap = (direction == Direction.right and at_right_edge())
    or (direction == Direction.left and at_left_edge())
    or (direction == Direction.up and at_top_edge())
    or (direction == Direction.down and at_bottom_edge())
  if will_wrap then
    dir_key = DirectionKeysReverse[direction]
  end

  next_win_or_wrap(will_wrap, dir_key)
  local buf_2 = vim.api.nvim_get_current_buf()
  local win_2 = vim.api.nvim_get_current_win()
  local win_view_2 = vim.fn.winsaveview()

  -- special case, same buffer in both windows, just swap cursor/scroll position
  if buf_1 == buf_2 then
    -- temporarily turn off folds to prevent jumping around the buffer
    local win_1_folds_enabled = vim.api.nvim_get_option_value('foldenable', { win = win_1 })
    local win_2_folds_enabled = vim.api.nvim_get_option_value('foldenable', { win = win_2 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_1 })
    vim.api.nvim_set_option_value('foldenable', false, { win = win_2 })

    vim.api.nvim_set_current_win(win_1)
    vim.fn.winrestview(win_view_2)
    vim.api.nvim_set_current_win(win_2)
    vim.fn.winrestview(win_view_1)

    -- revert `foldenable` option
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

vim.tbl_map(function(direction)
  M[string.format('resize_%s', direction)] = function(amount)
    local eventignore_orig = vim.deepcopy(vim.o.eventignore)
    set_eventignore()
    local cur_win_id = vim.api.nvim_get_current_win()
    is_resizing = true
    amount = amount or (vim.v.count1 * config.default_amount)
    local ok, error = pcall(resize, direction, amount)
    if not ok then
      log.error('failed to resize: %s', error)
    end
    -- guarantee we haven't moved the cursor by accident
    pcall(vim.api.nvim_set_current_win, cur_win_id)
    is_resizing = false
    -- luacheck:ignore
    vim.o.eventignore = eventignore_orig
  end
  M[string.format('move_cursor_%s', direction)] = function(opts)
    is_resizing = false
    local ok, error = pcall(move_cursor, direction, opts)
    if not ok then
      log.error('failed to move cursor: %s', error)
    end
  end
  M[string.format('swap_buf_%s', direction)] = function(opts)
    is_resizing = false
    local ok, error = pcall(swap_bufs, direction, opts)
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
  local win = mux_utils.get_previous_win()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

function M.update_layout_details()
  mux.update_layout_details()
end

return M
