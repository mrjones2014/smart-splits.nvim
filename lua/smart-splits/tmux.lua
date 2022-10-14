local M = {}

local function get_socket_path()
  local tmux = vim.env.TMUX
  if not tmux or #tmux == 0 then
    return nil
  end

  return vim.split(tmux, ',')[1]
end

local function tmux_exec(cmd)
  local socket = get_socket_path()
  if not socket then
    return nil
  end

  local cmd_str = string.format('tmux -S %s %s', socket, cmd)
  return vim.fn.system(cmd_str)
end

function M.current_session_is_tmux()
  return get_socket_path() ~= nil
end

---Try to get current tmux pane ID
---returns nil if failed or not in a tmux session.
---@return string|nil
function M.current_pane_id()
  local _, id = pcall(function()
    local output = tmux_exec('display-message -p "#{pane_id}"')
    if not output or #output == 0 then
      return nil
    end

    output = output:gsub('\n', '')
    return output
  end)

  return id
end

---Move to tmux pane directionally
---@param direction 'h'|'j'|'k'|'l'
---@return boolean true if command succeeded, false otherwise
function M.next_pane(direction)
  direction = string.upper(direction)
  local ok, _ = pcall(function()
    tmux_exec(string.format('select-pane -%s', direction))
  end)

  return ok
end

return M
