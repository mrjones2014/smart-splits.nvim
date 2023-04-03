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
  return vim.fn.system(command)
end

function M.current_pane_id()
  local output = wezterm_exec({ 'list-clients', '--format=json' })
  local data = vim.json.decode(output)
  if #data == 0 then
    return nil
  end
  -- if more than one client, get the active one
  if #data > 1 then
    table.sort(data, function(a, b)
      return a.idle_time.nanos < b.idle_time.nanos
    end)
  end
  return data[1].focused_pane_id
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
