local types = require('smart-splits.types')
local Direction = types.Direction
local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local log = lazy.require_on_exported_call('smart-splits.log')

local dir_keys_herdr = {
  [Direction.left] = 'left',
  [Direction.right] = 'right',
  [Direction.up] = 'up',
  [Direction.down] = 'down',
}

-- herdr split only supports 'right' and 'down'; for left/up we split then swap
local split_dir_herdr = {
  [Direction.left] = 'right',
  [Direction.right] = 'right',
  [Direction.up] = 'down',
  [Direction.down] = 'down',
}

local registered_pane_id

local function marker_dir()
  local cache_home = vim.env.XDG_CACHE_HOME
  if cache_home == nil or cache_home == '' then
    cache_home = (vim.env.HOME or vim.fn.expand('~')) .. '/.cache'
  end
  return cache_home .. '/smart-splits.nvim/herdr-panes'
end

local function marker_path(pane_id)
  return marker_dir() .. '/' .. tostring(pane_id)
end

local function nvim_server_address()
  local servername = vim.v.servername
  if servername ~= nil and servername ~= '' then
    return servername
  end
  return nil
end

local function write_marker(pane_id)
  pcall(vim.fn.mkdir, marker_dir(), 'p')

  local lines = {
    'version=2',
    'pid=' .. tostring(vim.fn.getpid()),
  }
  local server = nvim_server_address()
  if server then
    table.insert(lines, 'server=' .. server)
  end
  if vim.v.progpath and vim.v.progpath ~= '' then
    table.insert(lines, 'nvim=' .. vim.v.progpath)
  end

  pcall(vim.fn.writefile, lines, marker_path(pane_id))
end

local function remove_marker(pane_id)
  pcall(vim.fn.delete, marker_path(pane_id))
end

local function herdr_result(output, key)
  if not output or #output == 0 then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= 'table' then
    return nil
  end
  local result = decoded.result or decoded
  if key then
    return result[key]
  end
  return result
end

local function herdr_exec(args)
  local cli_path = config.herdr_cli_path or 'herdr'
  local cmd = vim.list_extend({ cli_path }, args)
  local ok, output, code = pcall(require('smart-splits.utils').system, cmd)
  if not ok then
    log.debug('herdr command failed: %s', table.concat(cmd, ' '))
    return nil, 1
  end
  return output, code
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = 'herdr'

function M.is_in_session()
  return vim.env.HERDR_SOCKET_PATH ~= nil and vim.env.HERDR_SOCKET_PATH ~= ''
end

function M.current_pane_id()
  if not M.is_in_session() then
    return nil
  end

  local output, code = herdr_exec({ 'pane', 'list' })
  local panes = code == 0 and herdr_result(output, 'panes') or nil
  if type(panes) == 'table' then
    for _, pane in ipairs(panes) do
      if pane.focused == true and pane.pane_id ~= nil then
        return tostring(pane.pane_id)
      end
    end
  end

  -- Fallback to the pane this Neovim process was launched in.
  local pane_id = vim.env.HERDR_PANE_ID
  if pane_id and #pane_id > 0 then
    return tostring(pane_id)
  end

  local current_output, current_code = herdr_exec({ 'pane', 'current' })
  local pane = current_code == 0 and herdr_result(current_output, 'pane') or nil
  if type(pane) == 'table' and pane.pane_id ~= nil then
    return tostring(pane.pane_id)
  end
  return nil
end

function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return false
  end
  local dir = dir_keys_herdr[direction]
  if not dir then
    return false
  end

  local output, code = herdr_exec({ 'pane', 'edges', '--current' })
  local edges = code == 0 and herdr_result(output, 'edges') or nil
  if type(edges) == 'table' and edges[dir] ~= nil then
    return edges[dir] == true
  end

  local neighbor_output, neighbor_code = herdr_exec({ 'pane', 'neighbor', '--direction', dir, '--current' })
  local neighbor = neighbor_code == 0 and herdr_result(neighbor_output, 'neighbor') or nil
  return type(neighbor) == 'table' and neighbor.neighbor_pane_id == nil
end

function M.current_pane_is_zoomed()
  if not M.is_in_session() then
    return false
  end
  local output, code = herdr_exec({ 'pane', 'layout', '--current' })
  if code ~= 0 or not output then
    return false
  end
  local layout = herdr_result(output, 'layout')
  return type(layout) == 'table' and layout.zoomed == true
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end
  local dir = dir_keys_herdr[direction]
  if not dir then
    return false
  end
  local _, code = herdr_exec({ 'pane', 'focus', '--direction', dir, '--current' })
  return code == 0
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end
  local dir = dir_keys_herdr[direction]
  if not dir then
    return false
  end
  local _, code = herdr_exec({ 'pane', 'resize', '--direction', dir, '--amount', tostring(amount), '--current' })
  return code == 0
end

function M.split_pane(direction, size)
  if not M.is_in_session() then
    return false
  end
  local split_dir = split_dir_herdr[direction]
  if not split_dir then
    return false
  end

  local args = { 'pane', 'split', '--direction', split_dir, '--current', '--focus' }
  local need_swap
  if direction == Direction.left then
    need_swap = 'left'
  elseif direction == Direction.up then
    need_swap = 'up'
  end
  if size then
    table.insert(args, '--ratio')
    table.insert(args, tostring(size))
  end
  local _, split_code = herdr_exec(args)
  if need_swap ~= nil then
    local _, swap_code = herdr_exec({ 'pane', 'swap', '--direction', need_swap, '--current' })
    M.update_mux_layout_details()
    return split_code == 0 and swap_code == 0
  end
  M.update_mux_layout_details()
  return split_code == 0
end

function M.on_init()
  local pane_id = M.current_pane_id()
  if not pane_id then
    return
  end
  registered_pane_id = tostring(pane_id)
  write_marker(registered_pane_id)
  vim.fn.jobstart({
    config.herdr_cli_path or 'herdr',
    'pane',
    'report-agent',
    registered_pane_id,
    '--source',
    'smart-splits',
    '--agent',
    'neovim',
    '--state',
    'idle',
  }, { detach = true })
end

function M.on_exit()
  local pane_id = registered_pane_id or M.current_pane_id()
  if not pane_id then
    return
  end
  remove_marker(pane_id)
  vim.fn.jobstart({
    config.herdr_cli_path or 'herdr',
    'pane',
    'release-agent',
    tostring(pane_id),
    '--source',
    'smart-splits',
    '--agent',
    'neovim',
  }, { detach = true })
  registered_pane_id = nil
end

function M.update_mux_layout_details()
  -- Not implemented yet - check Kitty mux for reference
end

return M
