local M = {}

local function resize(direction, amount)
  amount = amount or 3
  -- account for bufferline, status line, and cmd line
  local is_full_height = vim.api.nvim_win_get_height(0) == vim.o.lines - 2 - vim.o.cmdheight
  local is_full_width = vim.api.nvim_win_get_width(0) == vim.o.columns

  -- don't try to horizontally resize a full width window
  if (direction == 'left' or direction == 'right') and is_full_width then
    return
  end

  -- don't try to vertically resize a full height window
  if (direction == 'down' or direction == 'up') and is_full_height then
    return
  end

  local cur_win = vim.api.nvim_get_current_win()
  -- vertical
  if direction == 'down' or direction == 'up' then
    vim.cmd('wincmd k')
    local new_win = vim.api.nvim_get_current_win()
    vim.cmd('wincmd k')
    local new_win2 = vim.api.nvim_get_current_win()
    for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
      vim.cmd('wincmd j')
    end
    local new_win3 = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(cur_win)
    -- top edge or middle of >2
    if cur_win == new_win or (cur_win ~= new_win3 and new_win2 ~= new_win3) then
      if direction == 'down' then
        vim.cmd('resize +' .. amount)
      else
        vim.cmd('resize -' .. amount)
      end
    else
      -- bottom edge
      if direction == 'down' then
        vim.cmd('resize -' .. amount)
      else
        vim.cmd('resize +' .. amount)
      end
    end
  else
    vim.cmd('wincmd h')
    local new_win = vim.api.nvim_get_current_win()
    vim.cmd('wincmd h')
    local new_win2 = vim.api.nvim_get_current_win()
    for _ = 0, #vim.api.nvim_tabpage_list_wins(0), 1 do
      vim.cmd('wincmd l')
    end
    local new_win3 = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(cur_win)
    -- left edge or middle of >2
    if cur_win == new_win or (cur_win ~= new_win3 and new_win2 ~= new_win3) then
      if direction == 'right' then
        vim.cmd('vertical resize +' .. amount)
      else
        vim.cmd('vertical resize -' .. amount)
      end
    else
      -- not top edge
      if direction == 'right' then
        vim.cmd('vertical resize -' .. amount)
      else
        vim.cmd('vertical resize +' .. amount)
      end
    end
  end
end

vim.tbl_map(function(direction)
  M[string.format('resize_%s', direction)] = function(amount)
    resize(direction, amount)
  end
end, {
  'left',
  'right',
  'up',
  'down',
})

return M
