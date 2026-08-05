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

-- It is very expensive to ask zellij for the current pane id.
-- We also don't need the ID to move to the next pane.
-- However, SmartSplitsMultiplexer (and ./init.lua) demands that we return a number.
-- So let's just return -1
function M.current_pane_id()
  return -1
end

-- Not supported yet: https://github.com/mrjones2014/smart-splits.nvim/issues/477
function M.current_pane_at_edge()
  return false
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
  return vim.env.ZELLIJ ~= nil
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

function M.split_pane(direction, _size) ---@diagnostic disable-line: unused-local
  return false
end

-- size is not supported on zellij
-- function M.split_pane(direction, _size) ---@diagnostic disable-line: unused-local
--   -- zellij only splits right and down; for the others,
--   -- we must split right and down then swap the panes
--   local args = { 'action', 'new-pane' }
--   local need_swap
--   if direction == Direction.left then
--     table.insert(args, 'right')
--     need_swap = 'right'
--   elseif direction == Direction.up then
--     table.insert(args, 'down')
--     need_swap = 'down'
--   else
--     table.insert(args, direction)
--   end
--   local _, split_code = zellij_exec(args)
--   if need_swap ~= nil then
--     local _, swap_code = zellij_exec({ 'action', 'move-pane', need_swap })
--     M.update_mux_layout_details()
--     return split_code == 0 and swap_code == 0
--   end
--   M.update_mux_layout_details()
--   return split_code == 0
-- end

function M.update_mux_layout_details()
  -- Not implemented yet - check Kitty mux for reference
end

return M
