local M = {}

--- Reset all windows to a single window, close all other windows
function M.reset_editor()
  vim.cmd('silent! %bwipeout!')
  vim.cmd('silent! only!')
  -- reset options
  vim.o.splitright = false
  vim.o.splitbelow = false
  vim.o.eventignore = ''
end

--- Create a horizontal layout with `n` vertical splits (side by side)
--- Returns the list of window IDs left-to-right
---@param n number
---@return number[]
function M.create_vsplits(n)
  M.reset_editor()
  local wins = { vim.api.nvim_get_current_win() }
  for _ = 2, n do
    vim.cmd('vsplit')
    table.insert(wins, vim.api.nvim_get_current_win())
  end
  -- wins are in order of creation; re-sort left to right by column position
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)
  return wins
end

--- Create a vertical layout with `n` horizontal splits (stacked)
--- Returns the list of window IDs top-to-bottom
---@param n number
---@return number[]
function M.create_hsplits(n)
  M.reset_editor()
  local wins = { vim.api.nvim_get_current_win() }
  for _ = 2, n do
    vim.cmd('split')
    table.insert(wins, vim.api.nvim_get_current_win())
  end
  -- sort top to bottom by row position
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
  end)
  return wins
end

--- Focus a specific window
---@param win number window ID
function M.focus(win)
  vim.api.nvim_set_current_win(win)
end

--- Get current window ID
---@return number
function M.curwin()
  return vim.api.nvim_get_current_win()
end

--- Set a buffer in a window to a specific filetype
---@param win number
---@param ft string
function M.set_filetype(win, ft)
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_set_option_value('filetype', ft, { buf = buf })
end

--- Set a buffer in a window to a specific buftype
---@param win number
---@param bt string
function M.set_buftype(win, bt)
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_set_option_value('buftype', bt, { buf = buf })
end

--- Create a fresh buffer in a window so each window has a unique buffer
---@param wins number[]
function M.unique_buffers(wins)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(win, buf)
  end
end

return M
