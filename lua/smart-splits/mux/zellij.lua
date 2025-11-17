local Direction = require('smart-splits.types').Direction
local lazy = require('smart-splits.lazy')
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]
local log = require('smart-splits.log')

local function zellij_exec(cmd)
  local command = vim.deepcopy(cmd)
  table.insert(command, 1, 'zellij')
  return require('smart-splits.utils').system(command)
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = 'zellij'

function M.current_pane_id()
  local output = vim.split(zellij_exec({ 'action', 'list-clients' }), '\n', { trimempty = true })
  if not output[2] then
    return nil
  end

  -- The output format is like
  -- ```
  -- CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND
  -- 1         terminal_0     /path/to/nvim --cmd lua print('some arguments')
  -- ```
  -- We are looking for the value `0` here in the `terminal_0` chunk.
  -- The `terminal_` prefix might be something else, for example if a plugin's UI
  -- is currently focused, but we still need to know the pane ID, so we're using the
  -- `%w+` pattern to match any word prefix. Then we capture the ID with the `%d` pattern
  -- in the capture group.
  local pane_id = string.match(output[2], '%S+%s+%w+_(%d+)')
  return pane_id
end

function M.current_pane_at_edge()
  local pane_id = M.current_pane_id()
  if pane_id == nil then
    log.warn('could not get zeillij pane id')
    return false
  end
  zellij_exec({ 'action', 'move-focus', Direction.left })
  local new_pane_id = M.current_pane_id()

  if new_pane_id == nil then
    log.warn('could not get zeillij pane id')
    return false
  end

  -- move back to original pane
  zellij_exec({ 'action', 'move-focus', Direction.right })

  return pane_id == new_pane_id
end

-- amount is not supported on zellij
function M.resize_pane(direction, _amount) ---@diagnostic disable-line: unused-local
  if not M.is_in_session() then
    return false
  end

  local _, code = zellij_exec({ 'action', 'resize', 'increase', direction })
  return code == 0
end

function M.is_in_session()
  return M.current_pane_id() ~= nil
end

function M.current_pane_is_zoomed()
  return false
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end
  local action = 'move-focus'
  if config.zellij_move_focus_or_tab and (direction == Direction.left or direction == Direction.right) then
    action = 'move-focus-or-tab'
  end
  local _, code = zellij_exec({ 'action', action, direction })
  return code == 0
end

-- size is not supported on zellij
function M.split_pane(direction, _size) ---@diagnostic disable-line: unused-local
  -- zellij only splits right and down; for the others,
  -- we must split right and down then swap the panes
  local args = { 'action', 'new-pane' }
  local need_swap
  if direction == Direction.left then
    table.insert(args, 'right')
    need_swap = 'right'
  elseif direction == Direction.up then
    table.insert(args, 'down')
    need_swap = 'down'
  else
    table.insert(args, direction)
  end
  local _, split_code = zellij_exec(args)
  if need_swap ~= nil then
    local _, swap_code = zellij_exec({ 'action', 'move-pane', need_swap })
    M.update_mux_layout_details()
    return split_code == 0 and swap_code == 0
  end
  M.update_mux_layout_details()
  return split_code == 0
end

function M.update_mux_layout_details()
  -- Not implemented yet - check Kitty mux for reference
end

return M
