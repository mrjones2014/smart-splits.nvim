local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local utils = require('smart-splits.utils')
local types = require('smart-splits.types')
local Direction = types.Direction
local FloatWinBehavior = types.FloatWinBehavior

local M = {}

---@enum WinPosition
M.WinPosition = {
  start = 0,
  middle = 1,
  last = 2,
}

---@enum DirectionKeys
M.DirectionKeys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

---@enum DirectionKeysReverse
M.DirectionKeysReverse = {
  left = 'l',
  right = 'h',
  up = 'j',
  down = 'k',
}

---@enum WincmdResizeDirection
M.WincmdResizeDirection = {
  bigger = '+',
  smaller = '-',
}

---@param winid number|nil window ID, defaults to current window (0)
---@return boolean
function M.is_ignored_win(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid or 0)
  return vim.tbl_contains(config.ignored_buftypes, vim.api.nvim_get_option_value('buftype', { buf = bufnr }))
    or vim.tbl_contains(config.ignored_filetypes, vim.api.nvim_get_option_value('filetype', { buf = bufnr }))
end

---@param dir_key DirectionKeys
---@return number|nil window ID of neighbor, or nil if at edge
function M.neighbor_win_id(dir_key)
  local cur = vim.fn.winnr()
  local neighbor = vim.fn.winnr(dir_key)
  if neighbor == cur then
    return nil
  end
  return vim.fn.win_getid(neighbor)
end

---@param winnr number|nil window ID, defaults to current window
---@return boolean
function M.is_full_height(winnr)
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
function M.is_full_width(winnr)
  return vim.api.nvim_win_get_width(winnr or 0) == vim.o.columns
end

---@return boolean
function M.at_top_edge()
  return vim.fn.winnr() == vim.fn.winnr('k')
end

---@return boolean
function M.at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

---@return boolean
function M.at_left_edge()
  return vim.fn.winnr() == vim.fn.winnr('h')
end

---@return boolean
function M.at_right_edge()
  return vim.fn.winnr() == vim.fn.winnr('l')
end

---@param direction SmartSplitsDirection
---@return WinPosition
function M.win_position(direction)
  if direction == Direction.left or direction == Direction.right then
    if M.at_left_edge() then
      return M.WinPosition.start
    end
    if M.at_right_edge() then
      return M.WinPosition.last
    end
    return M.WinPosition.middle
  end

  if M.at_top_edge() then
    return M.WinPosition.start
  end
  if M.at_bottom_edge() then
    return M.WinPosition.last
  end
  return M.WinPosition.middle
end

---@param direction DirectionKeys
---@param skip_ignore_lists boolean|nil defaults to false
---@param is_resizing boolean
function M.next_window(direction, skip_ignore_lists, is_resizing)
  local cur_win = vim.api.nvim_get_current_win()
  if direction == M.DirectionKeys.down or direction == M.DirectionKeys.up then
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

---@param mux_callback fun()|nil
---@return boolean
function M.handle_floating_window(mux_callback)
  if not utils.is_floating_window() then
    return false
  end

  if config.float_win_behavior == FloatWinBehavior.previous then
    local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
    if utils.is_floating_window(prev_win) then
      return true
    end
    vim.api.nvim_set_current_win(prev_win)
    return false
  elseif config.float_win_behavior == FloatWinBehavior.mux then
    if mux_callback then
      mux_callback()
    end
    return true
  end

  return false
end

function M.set_eventignore()
  local eventignore = vim.o.eventignore
  if #eventignore > 0 and not vim.endswith(eventignore, ',') then
    eventignore = eventignore .. ','
  end
  eventignore = eventignore .. table.concat(config.ignored_events or {}, ',')
  -- luacheck:ignore
  vim.o.eventignore = eventignore
end

---@param will_wrap boolean
---@param dir_key DirectionKeys
function M.next_win_or_wrap(will_wrap, dir_key)
  vim.api.nvim_set_current_win(
    vim.fn.win_getid(vim.fn.winnr(string.format('%s%s', will_wrap and '99999' or vim.v.count1, dir_key)))
  )
end

return M
