local M = {}

function M.tbl_find(tbl, predicate)
  for idx, value in ipairs(tbl) do
    if predicate(value) then
      return value, idx
    end
  end

  return nil
end

---Check if a window is a floating window
---@param win_id number|nil window ID to check, defaults to current window (0)
---@return boolean
function M.is_floating_window(win_id)
  win_id = win_id or 0
  local win_cfg = vim.api.nvim_win_get_config(win_id)
  return win_cfg and (win_cfg.relative ~= '' or not win_cfg.relative)
end

local executables_cache = {}

---Run a system command.
---@param cmd string[] command arguments
---@param callback function |nil optional callback for async execution
---@return string|nil output|nil, number|nil exit_code|nil the stderr/stdout and the exit code
function M.system(cmd, callback)
  if #cmd == 0 then
    error('No command provided')
  end

  executables_cache[cmd[1]] = executables_cache[cmd[1]] or vim.fn.executable(cmd[1]) == 1
  if not executables_cache[cmd[1]] then
    error(string.format('`%s` is not executable (not found on `$PATH`)', cmd[1]))
  end

  if callback and type(callback) == 'function' then
    vim.system(cmd, { text = true }, callback)
    return
  end
  local result = vim.system(cmd, { text = true }):wait()
  return result.code == 0 and (result.stdout or '') or (result.stderr or ''), result.code
end

return M
