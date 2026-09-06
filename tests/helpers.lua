local M = {}

---Close every window but one and wipe all buffers.
function M.reset_editor()
  vim.cmd('silent! %bwipeout!')
  vim.cmd('silent! only!')
  vim.o.splitright = false
  vim.o.splitbelow = false
  vim.o.eventignore = ''
end

---Reset the plugin's own state, so each spec starts from the defaults.
function M.reset_plugin()
  require('smart-splits.config').reset() ---@diagnostic disable-line: invisible
  require('smart-splits.backend').reset()
  require('smart-splits.log').reset()
end

---Create `n` windows side by side, returned left to right.
---@param n number
---@return number[]
function M.create_vsplits(n)
  M.reset_editor()
  local wins = { vim.api.nvim_get_current_win() }
  for _ = 2, n do
    vim.cmd('vsplit')
    table.insert(wins, vim.api.nvim_get_current_win())
  end
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)
  return wins
end

---Create `n` stacked windows, returned top to bottom.
---@param n number
---@return number[]
function M.create_hsplits(n)
  M.reset_editor()
  local wins = { vim.api.nvim_get_current_win() }
  for _ = 2, n do
    vim.cmd('split')
    table.insert(wins, vim.api.nvim_get_current_win())
  end
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
  end)
  return wins
end

---@param win number
function M.focus(win)
  vim.api.nvim_set_current_win(win)
end

---@return number
function M.curwin()
  return vim.api.nvim_get_current_win()
end

---@param win number
---@param ft string
function M.set_filetype(win, ft)
  vim.api.nvim_set_option_value('filetype', ft, { buf = vim.api.nvim_win_get_buf(win) })
end

---@param win number
---@param bt string
function M.set_buftype(win, bt)
  vim.api.nvim_set_option_value('buftype', bt, { buf = vim.api.nvim_win_get_buf(win) })
end

---Give each window its own buffer.
---@param wins number[]
function M.unique_buffers(wins)
  for _, win in ipairs(wins) do
    vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, true))
  end
end

---A backend that records its calls. Pass `overrides` to replace any protocol
---field, including setting one to `false` to leave it out entirely.
---@param overrides table|nil
---@return SmartSplitsBackend backend
---@return table[] calls each entry is `{ op, ... }`
function M.mock_backend(overrides)
  overrides = overrides or {}
  local calls = {}

  local function record(op, handled)
    return function(...)
      table.insert(calls, { op, ... })
      return handled
    end
  end

  local backend = {
    name = 'mock',
    protocol_version = '3.0.0',
    detect = record('detect', true),
    move = record('move', false),
    resize = record('resize', false),
  }

  for key, value in pairs(overrides) do
    backend[key] = value ~= false and value or nil
  end

  return backend, calls
end

---Names of the operations recorded by `mock_backend`, in order.
---@param calls table[]
---@return string[]
function M.ops(calls)
  return vim.tbl_map(function(call)
    return call[1]
  end, calls)
end

---The first recorded call to the given operation, arguments included.
---@param calls table[]
---@param op string
---@return table|nil
function M.find_call(calls, op)
  for _, call in ipairs(calls) do
    if call[1] == op then
      return call
    end
  end
  return nil
end

return M
