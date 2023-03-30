local M = {}

local dir_keys_wezterm = {
  left = 'Left',
  right = 'Right',
  down = 'Down',
  up = 'Up',
}

local function wezterm_exec(cmd)
  local command = vim.deepcopy(cmd)
  table.insert(command, 1, 'wezterm')
  table.insert(command, 2, 'cli')
  vim.fn.system(command)
end

function M.current_pane_id()
  local pane_str = vim.env.WEZTERM_PANE
  if not pane_str then
    return nil
  end
  local ok, id = pcall(tonumber, pane_str)
  if ok then
    return id
  else
    return nil
  end
end

function M.current_pane_at_edge(direction)
  local pane_id = M.current_pane_id()
  wezterm_exec({ 'activate-pane-direction', direction })
  local new_pane_id = M.current_pane_id()
  wezterm_exec({ 'activate-pane', '--pane-id', pane_id })
  return pane_id == new_pane_id
end

function M.is_in_session()
  return M.current_pane_id() ~= nil
end

function M.current_pane_is_zoomed()
  -- wezterm doesn't currently have a way to tell this with the CLI
  return false
end

---Move to wezterm pane directionally
---@param direction 'left'|'right'|'up'|'down'
---@return boolean true if command succeeded, false otherwise
function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end

  direction = dir_keys_wezterm[direction] ---@diagnostic disable-line
  local ok, _ = pcall(function()
    wezterm_exec({ 'activate-pane-direction', direction })
  end)

  return ok
end

return M
