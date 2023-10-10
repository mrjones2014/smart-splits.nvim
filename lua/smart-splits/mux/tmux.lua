local types = require('smart-splits.types')
local Direction = types.Direction

local dir_keys_tmux = {
  [Direction.left] = 'L',
  [Direction.right] = 'R',
  [Direction.up] = 'U',
  [Direction.down] = 'D',
}

local function get_socket_path()
  local tmux = vim.env.TMUX
  if not tmux or #tmux == 0 then
    return nil
  end

  return vim.split(tmux, ',', { trimempty = true })[1]
end

---@param args (string|number)[]
---@param as_list boolean|nil
---@return nil
local function tmux_exec(args, as_list)
  local socket = get_socket_path()
  if not socket then
    return nil
  end

  local cmd = vim.list_extend({ 'tmux', '-S', socket }, args, 1, #args)
  if as_list then
    return vim.fn.systemlist(cmd) --[[ @as string[] ]]
  end
  return vim.fn.system(cmd)
end

---@type SmartSplitsMultiplexer
local M = {}

M.type = 'tmux'

function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return false
  end

  local edge
  if direction == Direction.up then
    edge = 'top'
  elseif direction == Direction.down then
    edge = 'bottom'
  elseif direction == Direction.left then
    edge = 'left'
  elseif direction == Direction.right then
    edge = 'right'
  else
    return false
  end

  local tmux_expr = string.format('#{&&:#{pane_active},#{pane_at_%s}}', edge)
  local result = tmux_exec({ 'list-panes', '-f', tmux_expr }, true)

  return type(result) == 'table' and #result == 1
end

function M.is_in_session()
  return get_socket_path() ~= nil
end

---Try to get current tmux pane ID
---returns nil if failed or not in a tmux session.
---@return string|nil
function M.current_pane_id()
  if not M.is_in_session() then
    return nil
  end

  local ok, id = pcall(function()
    local output = tmux_exec({ 'display-message', '-p', '#{pane_id}' }) --[[@as string]]
    if not output or #output == 0 then
      return nil
    end

    output = output:gsub('\n', '')
    return output
  end)

  if not ok then
    return nil
  else
    return id
  end
end

function M.current_pane_is_zoomed()
  local ok, is_zoomed = pcall(function()
    -- '#F' format strings outputs pane creation flags,
    -- if it it includes 'Z' then it's zoomed. A '*' indicates
    -- current pane, and since we're only listing current pane flags,
    -- we're expecting to see '*Z' if the current pane is zoomed
    local output = tmux_exec({ 'display-message', '-p', '#F' })
    if output then
      output = vim.trim(output --[[@as string]])
    end

    return output == '*Z'
  end)

  if ok then
    return is_zoomed
  else
    return ok
  end
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end

  direction = dir_keys_tmux[direction] ---@diagnostic disable-line
  local ok, _ = pcall(tmux_exec, { 'select-pane', string.format('-%s', direction) })
  return ok
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  direction = dir_keys_tmux[direction] ---@diagnostic disable-line
  local ok, _ = pcall(tmux_exec, { 'resize-pane', string.format('-%s', direction), amount })
  return ok
end

function M.split_pane(direction, size)
  local vert_or_horiz = (direction == Direction.left or direction == Direction.right) and '-h' or '-v'
  local args = { 'split-pane', vert_or_horiz }
  if direction == Direction.up or direction == Direction.left then
    table.insert(args, '-b')
  end
  if size then
    table.insert(args, '-l')
    table.insert(args, size)
  end
  local ok, _ = pcall(tmux_exec, args)
  return ok
end

return M
