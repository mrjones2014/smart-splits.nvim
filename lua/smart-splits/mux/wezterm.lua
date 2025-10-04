local Direction = require('smart-splits.types').Direction
local config = require('smart-splits.config')

local dir_keys_wezterm = {
  [Direction.left] = 'Left',
  [Direction.right] = 'Right',
  [Direction.down] = 'Down',
  [Direction.up] = 'Up',
}

local dir_keys_wezterm_splits = {
  [Direction.left] = '--left',
  [Direction.right] = '--right',
  [Direction.up] = '--top',
  [Direction.down] = '--bottom',
}

local function wezterm_exec(cmd)
  local command = vim.deepcopy(cmd)
  table.insert(command, 1, config.wezterm_cli_path)
  table.insert(command, 2, 'cli')
  return vim.fn.system(command)
end

local tab_id

-- Cache for current pane info to avoid repeated system calls
local pane_info_cache = nil
local pane_info_cache_time = 0
local PANE_INFO_CACHE_TTL = 0.1 -- 100ms cache TTL

local function init_tab_id()
  local output = wezterm_exec({ 'list', '--format', 'json' })
  if vim.v.shell_error ~= 0 or not output or #output == 0 then
    -- set to false to avoid trying again
    tab_id = false
    return
  end

  local data = vim.json.decode(output) --[[@as table]]
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
  -- Check cache first
  local now = vim.loop.hrtime() / 1e9
  if pane_info_cache and (now - pane_info_cache_time) < PANE_INFO_CACHE_TTL then
    return pane_info_cache
  end
  
  if tab_id == nil then
    init_tab_id()
  end

  if tab_id == false then
    pane_info_cache = nil
    pane_info_cache_time = now
    return nil
  end

  local output = wezterm_exec({ 'list', '--format', 'json' })
  if vim.v.shell_error ~= 0 or not output or #output == 0 then
    pane_info_cache = nil
    pane_info_cache_time = now
    return nil
  end

  local data = vim.json.decode(output) --[[@as table]]
  for _, pane in ipairs(data) do
    if pane.tab_id == tab_id and pane.is_active then
      pane_info_cache = pane
      pane_info_cache_time = now
      return pane
    end
  end

  pane_info_cache = nil
  pane_info_cache_time = now
  return nil
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = 'wezterm'

function M.current_pane_id()
  local current_pane = current_pane_info()
  -- uses API that requires newest version of Wezterm
  if current_pane ~= nil then
    return current_pane.pane_id
  end

  local output = wezterm_exec({ 'list-clients', '--format', 'json' }) --[[@as string]]
  local data = vim.json.decode(output) --[[@as table]]
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
    return ok and value == nil
  end
  local pane_id = M.current_pane_id()
  wezterm_exec({ 'activate-pane-direction', direction })
  -- Invalidate cache since we moved panes
  pane_info_cache = nil
  local new_pane_id = M.current_pane_id()
  wezterm_exec({ 'activate-pane', '--pane-id', pane_id })
  -- Invalidate cache again since we moved back
  pane_info_cache = nil
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
  local ok, _ = pcall(wezterm_exec, { 'activate-pane-direction', direction })
  if ok then
    -- Invalidate cache since we moved panes
    pane_info_cache = nil
  end
  return ok
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  direction = dir_keys_wezterm[direction] ---@diagnostic disable-line
  local ok, _ = pcall(wezterm_exec, { 'adjust-pane-size', '--amount', amount, direction })
  if ok then
    -- Invalidate cache since pane size changed (though pane_id won't change)
    pane_info_cache = nil
  end
  return ok
end

function M.split_pane(direction, size)
  local args = { 'split-pane', dir_keys_wezterm_splits[direction] }
  if size then
    table.insert(args, '--cells')
    table.insert(args, size)
  end
  local ok, _ = pcall(wezterm_exec, args)
  return ok
end

function M.on_init()
  local format_var = vim.fn['smart_splits#format_wezterm_var']
  local write_var = vim.fn['smart_splits#write_wezterm_var']
  write_var(format_var('true'))
end

function M.on_exit()
  local format_var = vim.fn['smart_splits#format_wezterm_var']
  local write_var = vim.fn['smart_splits#write_wezterm_var']
  write_var(format_var('false'))
end

return M
