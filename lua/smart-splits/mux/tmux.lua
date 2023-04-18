local types = require('smart-splits.types')
local Direction = types.Direction
local AtEdgeBehavior = types.AtEdgeBehavior

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

local function tmux_exec(cmd, as_list)
  local socket = get_socket_path()
  if not socket then
    return nil
  end

  local cmd_str = string.format('tmux -S %s %s', socket, cmd)
  if as_list then
    return vim.fn.systemlist(cmd_str) --[[ @as string[] ]]
  end
  return vim.fn.system(cmd_str)
end

---@type SmartSplitsMultiplexer
local M = {}

function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return false
  end

  local wrap_at_edge = require('smart-splits.config').at_edge == AtEdgeBehavior.wrap

  local edge
  local op
  if direction == Direction.up then
    edge = 'top'
    op = wrap_at_edge and '<=' or '<'
  elseif direction == Direction.down then
    edge = 'bottom'
    op = wrap_at_edge and '>' or '>='
  elseif direction == Direction.left then
    edge = 'left'
    op = wrap_at_edge and '<=' or '<'
  elseif direction == Direction.right then
    edge = 'right'
    op = wrap_at_edge and '>' or '>='
  else
    return false
  end

  local tmux_expr = string.format('#{pane_id}:#{pane_%s}:#{?pane_active,_active_,_no_}', edge)
  local panes = tmux_exec(string.format('list-panes -F "%s"', tmux_expr), true)
  local active_pane_output_line = vim.tbl_filter(function(line)
    return not not string.find(line, '_active_')
  end, panes --[[ @as string[] ]])[1]

  if not active_pane_output_line then
    -- no active pane?
    return false
  end

  local active_pane_id = active_pane_output_line:match('(%%[0-9]*):')
  local active_pane_coord = active_pane_output_line:match(':([0-9]*):')
  if not active_pane_id or not active_pane_coord then
    -- no active pane?
    return false
  end

  local pane_coords = vim.tbl_map(function(line)
    return line:match(':([0-9]*):')
  end, panes --[[ @as string[] ]])

  -- sort largest to smallest
  table.sort(pane_coords, function(a, b)
    return a > b
  end)

  local top_coord = pane_coords[1]

  local ok, value = pcall(function()
    local expr = string.format('return %s %s %s', tonumber(active_pane_coord), op, tonumber(top_coord))
    return loadstring(expr)()
  end)

  if not ok then
    return false
  else
    return value
  end
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
    local output = tmux_exec('display-message -p "#{pane_id}"') --[[@as string]]
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
    local output = tmux_exec("display-message -p '#F'")
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
  local ok, _ = pcall(function()
    tmux_exec(string.format('select-pane -%s', direction))
  end)

  return ok
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  direction = dir_keys_tmux[direction] ---@diagnostic disable-line
  local ok, _ = pcall(function()
    tmux_exec(string.format('resize-pane -%s %s', direction, amount))
  end)

  return ok
end

return M
