local M = {}

----------
-- CONFIG
----------

M.config = {
  ignored_buftypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  ignored_filetypes = {
    'NvimTree',
  },
  move_cursor_same_row = false,
}

function M.setup(config)
  M.config.ignored_buftypes = config.ignored_buftypes or M.config.ignored_buftypes
  M.config.ignored_filetypes = config.ignored_filetypes or M.config.ignored_filetypes
  if config.move_cursor_same_row ~= nil then
    M.config.move_cursor_same_row = config.move_cursor_same_row
  end
end

----------
-- PLUGIN
----------

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

local edge_cache = {}

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

local function next_window(direction)
  if direction == dir_keys.down or direction == dir_keys.up then
    vim.cmd('wincmd ' .. direction)
    return
  end

  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  vim.cmd('wincmd ' .. direction)
  local view = vim.fn.winsaveview()
  offset = offset - vim.api.nvim_win_get_position(0)[1]
  vim.cmd('normal! ' .. offset .. 'H')
  return view
end

local function at_top_edge()
  if edge_cache.top ~= nil then
    return edge_cache.top
  end

  local cur_win = vim.api.nvim_get_current_win()
  local view = next_window(dir_keys.up)
  local is_at_top = vim.api.nvim_get_current_win() == cur_win
  pcall(vim.fn.winrestview, view)
  vim.api.nvim_set_current_win(cur_win)
  edge_cache.top = is_at_top
  return is_at_top
end

local function at_bottom_edge()
  if edge_cache.bottom ~= nil then
    return edge_cache.bottom
  end

  local cur_win = vim.api.nvim_get_current_win()
  local view = next_window(dir_keys.down)
  local is_at_bottom = vim.api.nvim_get_current_win() == cur_win
  pcall(vim.fn.winrestview, view)
  vim.api.nvim_set_current_win(cur_win)
  edge_cache.bottom = is_at_bottom
  return is_at_bottom
end

local function at_left_edge()
  if edge_cache.left ~= nil then
    return edge_cache.left
  end

  local cur_win = vim.api.nvim_get_current_win()
  local view = next_window(dir_keys.left)
  local is_at_left = vim.api.nvim_get_current_win() == cur_win
  pcall(vim.fn.winrestview, view)
  vim.api.nvim_set_current_win(cur_win)
  edge_cache.left = is_at_left
  return is_at_left
end

local function at_right_edge()
  if edge_cache.right ~= nil then
    return edge_cache.right
  end

  local cur_win = vim.api.nvim_get_current_win()
  local view = next_window(dir_keys.right)
  local is_at_right = vim.api.nvim_get_current_win() == cur_win
  pcall(vim.fn.winrestview, view)
  vim.api.nvim_set_current_win(cur_win)
  edge_cache.right = is_at_right
  return is_at_right
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
  if current_pos == win_pos.start or current_pos == win_pos.middle then
    return direction == 'right' and '+' or '-'
  end

  return direction == 'right' and '-' or '+'
end

local function resize(direction, amount)
  amount = amount or 3

  -- don't try to horizontally resize a full width window
  if (direction == 'left' or direction == 'right') and is_full_width() then
    return
  end

  -- don't try to vertically resize a full height window
  if (direction == 'down' or direction == 'up') and is_full_height() then
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

local function move_cursor(direction, same_row)
  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  if direction == 'left' then
    if at_left_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd ' .. dir_keys.right)
      end
    else
      vim.cmd('wincmd ' .. dir_keys.left)
    end
  elseif direction == 'right' then
    if at_right_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd ' .. dir_keys.left)
      end
    else
      vim.cmd('wincmd ' .. dir_keys.right)
    end
  elseif direction == 'up' then
    if at_top_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd ' .. dir_keys.down)
      end
    else
      vim.cmd('wincmd ' .. dir_keys.up)
    end
  elseif at_bottom_edge() then
    for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
      vim.cmd('wincmd ' .. dir_keys.up)
    end
  else
    vim.cmd('wincmd ' .. dir_keys.down)
  end

  if
    (direction == 'left' or direction == 'right')
    and (same_row or (same_row == nil and M.config.move_cursor_same_row))
  then
    offset = offset - vim.api.nvim_win_get_position(0)[1]
    vim.cmd('normal! ' .. offset .. 'H')
  end
end

vim.tbl_map(function(direction)
  M[string.format('resize_%s', direction)] = function(amount)
    local cur_win_id = vim.api.nvim_get_current_win()
    edge_cache = {}
    resize(direction, amount)
    -- guarantee we haven't moved the cursor by accident
    vim.api.nvim_set_current_win(cur_win_id)
  end
  M[string.format('move_cursor_%s', direction)] = function(same_row)
    edge_cache = {}
    move_cursor(direction, same_row)
  end
end, {
  'left',
  'right',
  'up',
  'down',
})

return M
