local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log')
local config = lazy.require_on_index('smart-splits.config')
local types = require('smart-splits.types')
local Direction = types.Direction
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
    log.debug('Failed to get multiplexer pane ID')
    return false
  end

  local ok = multiplexer.next_pane(direction)
  if not ok then
    log.debug('Failed to select multiplexer pane')
    return false
  end
  local new_pane = multiplexer.current_pane_id()
  if not new_pane then
    log.debug('Failed to get multiplexer pane ID')
    return false
  end

  -- we've moved to a new multiplexer pane, finish
  if current_pane ~= new_pane then
    return true
  end

  return false
end

---@class SmartSplitsMuxApi
---@field private __mux SmartSplitsMultiplexer|nil
local M = {}

M.__mux = nil

---Get the currently configured multiplexer
---@return SmartSplitsMultiplexer|nil
function M.get()
  if M.__mux ~= nil then
    return M.__mux
  end

  if
    config.multiplexer_integration == nil
    or config.multiplexer_integration == false
    or #tostring(config.multiplexer_integration or '') == 0
  then
    return nil
  end

  local ok, mux = pcall(require, string.format('smart-splits.mux.%s', config.multiplexer_integration))
  if not ok then
    log.error(mux)
  else
    M.__mux = mux
  end

  return M.__mux
end

---Check if any multiplexer is enabled
---@return boolean
function M.is_enabled()
  return M.get() ~= nil
end

---Try moving with multiplexer
---@param direction SmartSplitsDirection direction to move
---@param will_wrap boolean whether to wrap around edge
---@param at_edge SmartSplitsAtEdgeBehavior behavior at edge
---@return boolean success
function M.move_pane(direction, will_wrap, at_edge)
  local ok, result = pcall(function()
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

    if at_edge == AtEdgeBehavior.wrap then
      return move_multiplexer_inner(directions_reverse[direction], multiplexer)
    end

    return false
  end)

  if not ok then
    log.error(result)
    return false
  end

  return result
end

---Try resizing with multiplexer
---@param direction SmartSplitsDirection direction to resize
---@param amount number amount to resize
---@return boolean success
function M.resize_pane(direction, amount)
  local ok, result = pcall(function()
    local multiplexer = M.get()
    if not multiplexer or not multiplexer.is_in_session() then
      return false
    end
    if config.disable_multiplexer_nav_when_zoomed and multiplexer.current_pane_is_zoomed() then
      return false
    end

    local resized = multiplexer.resize_pane(direction, amount)
    if not resized then
      log.debug('Failed to resize multiplexer pane')
    end

    return resized
  end)

  if not ok then
    log.error(result)
    return false
  end

  return result
end

---Try creating a new mux split pane.
---@param direction SmartSplitsDirection
---@param size number|nil
---@return boolean success
function M.split_pane(direction, size)
  local ok, result = pcall(function()
    local mux = M.get()
    if not mux or not mux.is_in_session() then
      return false
    end
    local did_split = mux.split_pane(direction, size)
    if not did_split then
      log.error('Failed to create a new mux pane')
    end
    return did_split
  end)

  if not ok then
    log.error(result)
    return false
  end

  return result
end

function M.update_layout_details()
  local ok, result = pcall(function()
    local mux = M.get()
    if not mux or not mux.is_in_session() then
      return
    end
    mux.update_mux_layout_details()
  end)

  if not ok then
    log.error(result)
  end
end

return M
