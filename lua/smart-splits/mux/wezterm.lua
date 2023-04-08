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

local tab_id

local function init_tab_id()
  local output = wezterm_exec({ 'list', '--format', 'json' })
  if vim.v.shell_error ~= 0 or not output or #output == 0 then
    -- set to false to avoid trying again
    tab_id = false
    return
  end

  local data = vim.json.decode(output)
  for _, pane in ipairs(data) do
    if tostring(pane.pane_id) == tostring(vim.env.WEZTERM_PANE) then
      tab_id = pane.tab_id
      return
    end
  end

  -- set to false to avoid trying again
  tab_id = false
end

local function current_pane_info()
  if tab_id == nil then
    init_tab_id()
  end

  if tab_id == false then
    return nil
  end

  local output = wezterm_exec({ 'list', '--format', 'json' })
  if vim.v.shell_error ~= 0 or not output or #output == 0 then
    return nil
  end

  local data = vim.json.decode(output)
  for _, pane in ipairs(data) do
    if pane.tab_id == tab_id and pane.is_active then
      return pane
    end
  end

  return nil
end

---@type Multiplexer
local M = {}

function M.current_pane_id()
  local current_pane = current_pane_info()
  -- uses API that requires newest version of Wezterm
  if current_pane ~= nil then
    return current_pane.pane_id
  end

  local output = wezterm_exec({ 'list-clients', '--format', 'json' })
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
  -- try the new way first
  local output = wezterm_exec({ 'get-pane-direction', direction })
  if vim.v.shell_error == 0 then
    local ok, value = pcall(tonumber, output)
    return ok and value ~= nil
  end
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
  local current_pane = current_pane_info()
  if current_pane then
    return current_pane.is_zoomed
  end

  return false
end

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

function M.resize_pane()
    vim.notify('[smart-splits.nvim] Resize pane not supported', vim.log.levels.ERROR)
end

return M
