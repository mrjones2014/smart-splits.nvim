local M = {}

----------
-- CONFIG
----------

M.ignored_buftypes = {
  'nofile',
  'quickfix',
  'prompt',
}

M.ignored_filetypes = {
  'NvimTree',
}

----------
-- PLUGIN
----------

local win_pos = {
  start = 0,
  middle = 1,
  last = 2,
}

local dir_keys = {
  ['h'] = 'left',
  ['j'] = 'down',
  ['k'] = 'up',
  ['l'] = 'right',
}
vim.tbl_add_reverse_lookup(dir_keys)

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

local function move_win(direction)
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
  local view = move_win(dir_keys.up)
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
  local view = move_win(dir_keys.down)
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
  local view = move_win(dir_keys.left)
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
  local view = move_win(dir_keys.right)
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
  print(current_pos)
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

  local cur_win_id = vim.api.nvim_get_current_win()
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
      vim.cmd('wincmd k')
      vim.cmd(string.format('resize %s%s', adjustment_plus_minus, amount))
      vim.cmd('wincmd j')
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
      vim.cmd('wincmd l')
      vim.cmd(string.format('vertical resize %s%s', adjustment_plus_minus, amount))
      vim.cmd('wincmd h')
    end
  end
end

local function move_cursor(direction)
  if direction == 'left' then
    if at_left_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd l')
      end
    else
      vim.cmd('wincmd h')
    end
  elseif direction == 'right' then
    if at_right_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd h')
      end
    else
      vim.cmd('wincmd l')
    end
  elseif direction == 'up' then
    if at_top_edge() then
      for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
        vim.cmd('wincmd j')
      end
    else
      vim.cmd('wincmd k')
    end
  elseif at_bottom_edge() then
    for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
      vim.cmd('wincmd k')
    end
  else
    vim.cmd('wincmd j')
  end
end

vim.tbl_map(function(direction)
  M[string.format('resize_%s', direction)] = function(amount)
    edge_cache = {}
    resize(direction, amount)
  end
  M[string.format('move_cursor_%s', direction)] = function()
    edge_cache = {}
    move_cursor(direction)
  end
end, {
  'left',
  'right',
  'up',
  'down',
})

return M
