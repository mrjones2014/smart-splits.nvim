local M = {}

---Try to get current tmux pane ID
---returns nil if failed.
---@return string|nil
function M.current_pane_id()
  local _, id = pcall(function()
    local output = vim.fn.system('tmux display-message -p "#{pane_id}"')
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
    vim.fn.system(string.format('tmux select-pane -%s', direction))
  end)

  return ok
end

return M
