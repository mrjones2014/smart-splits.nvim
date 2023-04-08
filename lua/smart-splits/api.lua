local M = {}

local config = require('smart-splits.config')
local mux = require('smart-splits.mux')

local win_pos = {
  start = 0,
  middle = 1,
  last = 2,
}

local dir_keys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

local dir_keys_reverse = {
  left = 'l',
  right = 'h',
  up = 'j',
  down = 'k',
}

local is_resizing = false

local function is_full_height(winnr)
  -- for vertical height account for tabline, status line, and cmd line
  local window_height = vim.o.lines - 1 - vim.o.cmdheight
  if (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) or vim.o.showtabline == 2 then
    window_height = window_height - 1
  end
  return vim.api.nvim_win_get_height(winnr or 0) == window_height
end

local function is_full_width(winnr)
  return vim.api.nvim_win_get_width(winnr or 0) == vim.o.columns
end

local function next_window(direction, skip_ignore_lists)
  local cur_win = vim.api.nvim_get_current_win()
  if direction == dir_keys.down or direction == dir_keys.up then
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
    and (vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype) or vim.tbl_contains(config.ignored_filetypes))
  then
    vim.api.nvim_set_current_win(cur_win)
    return nil
  end
  local view = vim.fn.winsaveview()
  offset = offset - vim.api.nvim_win_get_position(0)[1]
  vim.cmd('normal! ' .. offset .. 'H')
  return view
end

local function at_top_edge()
  return vim.fn.winnr() == vim.fn.winnr('k')
end

local function at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

local function at_left_edge()
  return vim.fn.winnr() == vim.fn.winnr('h')
end

local function at_right_edge()
  return vim.fn.winnr() == vim.fn.winnr('l')
end

function M.win_position(direction)
  if direction == 'left' or direction == 'right' then
    if at_left_edge() then
      return win_pos.start
    end

    if at_right_edge() then
      return win_pos.last
    end

    return win_pos.middle
  end

  if at_top_edge() then
    return win_pos.start
  end

  if at_bottom_edge() then
    return win_pos.last
  end

  return win_pos.middle
end

local function compute_direction_vertical(direction)
  local current_pos = M.win_position(direction)
  if current_pos == win_pos.start or current_pos == win_pos.middle then
    return direction == 'down' and '+' or '-'
  end

  return direction == 'down' and '-' or '+'
end

local function compute_direction_horizontal(direction)
  local current_pos = M.win_position(direction)
  local result
  if current_pos == win_pos.start or current_pos == win_pos.middle then
    result = direction == 'right' and '+' or '-'
  else
    result = direction == 'right' and '-' or '+'
  end

  local at_left = at_left_edge()
  local at_right = at_right_edge()
  -- special case - check if there is an ignored window to the left
  if direction == 'right' and result == '+' and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    next_window(dir_keys.left, true)
    if
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    then
      vim.api.nvim_set_current_win(cur_win)
      result = '-'
    end
  elseif direction == 'left' and result == '-' and at_left and at_right then
    local cur_win = vim.api.nvim_get_current_win()
    next_window(dir_keys.left, true)
    if
      vim.tbl_contains(config.ignored_buftypes, vim.bo.buftype)
      or vim.tbl_contains(config.ignored_filetypes, vim.bo.filetype)
    then
      vim.api.nvim_set_current_win(cur_win)
      result = '+'
    end
  end

  return result
end

local function resize(direction, amount)
  amount = amount or config.default_amount

  -- if a full width window and horizontall resize check if we can resize with multiplexer
  if (direction == 'left' or direction == 'right') and is_full_width() and mux.resize_pane(direction, amount) then
    return
  end

  -- if a full height window and vertical resize check if we can resize with multiplexer
  if (direction == 'down' or direction == 'up') and is_full_height() and mux.resize_pane(direction, amount) then
    return
  end

  if direction == 'down' or direction == 'up' then
    -- vertically
    local plus_minus = compute_direction_vertical(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('resize %s%s', plus_minus, amount))
    if M.win_position(direction) ~= win_pos.middle then
      return
    end

    local new_win_pos = vim.api.nvim_win_get_position(0)
    local adjustment_plus_minus
    if cur_win_pos[1] < new_win_pos[1] and plus_minus == '-' then
      adjustment_plus_minus = '+'
    elseif cur_win_pos[1] > new_win_pos[1] and plus_minus == '+' then
      adjustment_plus_minus = '-'
    end

    if at_bottom_edge() then
      if plus_minus == '+' then
        vim.cmd(string.format('resize -%s', amount))
        next_window(dir_keys.down)
        vim.cmd(string.format('resize -%s', amount))
      else
        vim.cmd(string.format('resize +%s', amount))
        next_window(dir_keys.down)
        vim.cmd(string.format('resize +%s', amount))
      end
      return
    end

    if adjustment_plus_minus ~= nil then
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      next_window(dir_keys.up)
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      next_window(dir_keys.down)
    end
  else
    -- horizontally
    local plus_minus = compute_direction_horizontal(direction)
    local cur_win_pos = vim.api.nvim_win_get_position(0)
    vim.cmd(string.format('vertical resize %s%s', plus_minus, amount))
    if M.win_position(direction) ~= win_pos.middle then
      return
    end

    local new_win_pos = vim.api.nvim_win_get_position(0)
    local adjustment_plus_minus
    if cur_win_pos[2] < new_win_pos[2] and plus_minus == '-' then
      adjustment_plus_minus = '+'
    elseif cur_win_pos[2] > new_win_pos[2] and plus_minus == '+' then
      adjustment_plus_minus = '-'
    end
    if adjustment_plus_minus ~= nil then
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      next_window(dir_keys.right)
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      next_window(dir_keys.left)
    end
  end
end

local function move_to_edge(at_edge_and_moving_to_edge, dir_key)
  -- if someone has more than 99999 windows then just LOL
  vim.api.nvim_set_current_win(
    vim.fn.win_getid(vim.fn.winnr(string.format('%s%s', at_edge_and_moving_to_edge and '99999' or '1', dir_key)))
  )
end

local function move_cursor(direction, same_row)
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  local dir_key = dir_keys[direction]

  local at_right = at_right_edge()
  local at_left = at_left_edge()
  local at_top = at_top_edge()
  local at_bottom = at_bottom_edge()

  -- are we at an edge and attempting to move in the direction of the edge we're already at?
  local at_edge_and_moving_to_edge = (direction == 'left' and at_left)
    or (direction == 'right' and at_right)
    or (direction == 'up' and at_top)
    or (direction == 'down' and at_bottom)

  local at_any_edge = at_right or at_left or at_top or at_bottom

  -- if at the edge, and moving towards the edge, check if we can move with multiplexer
  if at_any_edge and at_edge_and_moving_to_edge and mux.move_pane(direction, at_edge_and_moving_to_edge) then
    return
  end

  if config.wrap_at_edge == false then
    if
      (at_right and direction == 'right')
      or (at_left and direction == 'left')
      or (at_top and direction == 'up')
      or (at_bottom and direction == 'down')
    then
      return
    end
  end

  if at_edge_and_moving_to_edge then
    dir_key = dir_keys_reverse[direction]
  end

  move_to_edge(at_edge_and_moving_to_edge, dir_key)

  if
    (direction == 'left' or direction == 'right')
    and (same_row or (same_row == nil and config.move_cursor_same_row))
  then
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

local function swap_bufs(direction, opts)
  opts = opts or {}
  local buf_1 = vim.api.nvim_get_current_buf()
  local win_1 = vim.api.nvim_get_current_win()

  local dir_key = dir_keys[direction]
  local at_edge_and_moving_to_edge = (direction == 'right' and at_right_edge())
    or (direction == 'left' and at_left_edge())
    or (direction == 'up' and at_top_edge())
    or (direction == 'down' and at_bottom_edge())
  if at_edge_and_moving_to_edge then
    dir_key = dir_keys_reverse[direction]
  end

  move_to_edge(at_edge_and_moving_to_edge, dir_key)
  local buf_2 = vim.api.nvim_get_current_buf()
  local win_2 = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(win_2, buf_1)
  vim.api.nvim_win_set_buf(win_1, buf_2)
  local move_cursor_with_buf = opts.move_cursor
  if move_cursor_with_buf == nil then
    move_cursor_with_buf = config.cursor_follows_swapped_bufs
  end
  if not move_cursor_with_buf then
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
    pcall(resize, direction, amount)
    -- guarantee we haven't moved the cursor by accident
    vim.api.nvim_set_current_win(cur_win_id)
    is_resizing = false
    -- luacheck:ignore
    vim.o.eventignore = eventignore_orig
  end
  M[string.format('move_cursor_%s', direction)] = function(same_row)
    is_resizing = false
    pcall(move_cursor, direction, same_row)
  end
  M[string.format('swap_buf_%s', direction)] = function(opts)
    is_resizing = false
    swap_bufs(direction, opts)
  end
end, {
  'left',
  'right',
  'up',
  'down',
})

return M
