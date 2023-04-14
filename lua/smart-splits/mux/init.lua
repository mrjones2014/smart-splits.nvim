local config = require('smart-splits.config')
local types = require('smart-splits.types')
local Direction = types.Direction
local Multiplexer = types.Multiplexer
local AtEdgeBehavior = types.AtEdgeBehavior

local directions_reverse = {
  [Direction.left] = Direction.right,
  [Direction.right] = Direction.left,
  [Direction.up] = Direction.down,
  [Direction.down] = Direction.up,
}

local function move_multiplexer_inner(direction, multiplexer)
  local current_pane = multiplexer.current_pane_id()
  if not current_pane then
    vim.notify('[smart-splits.nvim] Failed to get multiplexer pane ID', vim.log.levels.ERROR)
    return false
  end

  local ok = multiplexer.next_pane(direction)
  if not ok then
    vim.notify('[smart-splits.nvim] Failed to select multiplexer pane', vim.log.levels.ERROR)
    return false
  end
  local new_pane = multiplexer.current_pane_id()
  if not new_pane then
    vim.notify('[smart-splits.nvim] Failed to get multiplexer pane ID', vim.log.levels.ERROR)
    return false
  end

  -- we've moved to a new multiplexer pane, finish
  if current_pane ~= new_pane then
    return true
  end

  return false
end

local M = {}

---Get the currently configured multiplexer
---@return Multiplexer|nil
function M.get()
  local mux = config.multiplexer_integration
  if mux == Multiplexer.tmux then
    return require('smart-splits.mux.tmux')
  elseif mux == Multiplexer.wezterm then
    return require('smart-splits.mux.wezterm')
  elseif mux == Multiplexer.kitty then
    return require('smart-splits.mux.kitty')
  else
    return nil
  end
end

---Check if any multiplexer is enabled
---@return boolean
function M.is_enabled()
  return M.get() ~= nil
end

---Try moving with multiplexer
---@param direction Direction direction to move
---@param will_wrap boolean whether to wrap around edge
---@param at_edge AtEdgeBehavior behavior at edge
---@return boolean whether we moved with multiplexer or not
function M.move_pane(direction, will_wrap, at_edge)
  at_edge = at_edge or config.at_edge
  local multiplexer = M.get()
  if not multiplexer or not multiplexer.is_in_session() then
    return false
  end

  if at_edge ~= AtEdgeBehavior.wrap and multiplexer.current_pane_at_edge(direction) then
    return false
  end

  if config.disable_multiplexer_nav_when_zoomed and multiplexer.current_pane_is_zoomed() then
    return false
  end

  local multiplexer_moved = move_multiplexer_inner(direction, multiplexer)
  if multiplexer_moved or not will_wrap then
    return multiplexer_moved
  end

  return move_multiplexer_inner(directions_reverse[direction], multiplexer)
end

---Try resizing with multiplexer
---@param direction Direction direction to resize
---@param amount number amount to resize
---@return boolean whether we resized with multiplexer or not
function M.resize_pane(direction, amount)
  local multiplexer = M.get()
  if not multiplexer or not multiplexer.is_in_session() then
    return false
  end
  if config.disable_multiplexer_nav_when_zoomed and multiplexer.current_pane_is_zoomed() then
    return false
  end

  local ok = multiplexer.resize_pane(direction, amount)
  if not ok then
    vim.notify('[smart-splits.nvim] Failed to resize multiplexer pane', vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
