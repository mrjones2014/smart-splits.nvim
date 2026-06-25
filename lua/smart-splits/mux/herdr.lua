local Direction = require('smart-splits.types').Direction

local dir_keys_herdr = {
  [Direction.left] = 'left',
  [Direction.right] = 'right',
  [Direction.down] = 'down',
  [Direction.up] = 'up',
}

local split_keys_herdr = {
  [Direction.left] = 'right',
  [Direction.right] = 'right',
  [Direction.up] = 'down',
  [Direction.down] = 'down',
}

local function herdr_exec(cmd)
  local command = vim.deepcopy(cmd)
  table.insert(command, 1, 'herdr')
  return require('smart-splits.utils').system(command)
end

local function herdr_exec_json(cmd)
  local output, code = herdr_exec(cmd)
  if code ~= 0 or not output or #output == 0 then
    return nil, code
  end

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok then
    return nil, code
  end

  return decoded, code
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = 'herdr'

function M.current_pane_id()
  local data = herdr_exec_json({ 'pane', 'list' })
  if data and data.result and data.result.panes then
    for _, pane in ipairs(data.result.panes) do
      if pane.focused then
        return pane.pane_id
      end
    end
  end

  local pane_id = vim.env.HERDR_PANE_ID
  if pane_id ~= nil and #pane_id > 0 then
    return pane_id
  end

  data = herdr_exec_json({ 'pane', 'current', '--current' })
  return data and data.result and data.result.pane and data.result.pane.pane_id or nil
end

function M.current_pane_at_edge(direction)
  local data = herdr_exec_json({ 'pane', 'edges', '--current' })
  if not data or not data.result or not data.result.edges then
    return false
  end

  return data.result.edges[dir_keys_herdr[direction]] == true
end

function M.is_in_session()
  return vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= ''
end

function M.current_pane_is_zoomed()
  return false
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end

  local data, code = herdr_exec_json({ 'pane', 'focus', '--direction', dir_keys_herdr[direction], '--current' })
  if code ~= 0 then
    return false
  end

  return data ~= nil and data.result ~= nil and data.result.focus ~= nil and data.result.focus.changed == true
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  local data, code = herdr_exec_json({
    'pane',
    'resize',
    '--direction',
    dir_keys_herdr[direction],
    '--amount',
    tostring(amount),
    '--current',
  })
  if code ~= 0 then
    return false
  end

  return data ~= nil and data.result ~= nil and data.result.resize ~= nil and data.result.resize.changed == true
end

function M.split_pane(direction, _size) ---@diagnostic disable-line: unused-local
  if not M.is_in_session() then
    return false
  end

  local split_direction = split_keys_herdr[direction]
  if split_direction == nil then
    return false
  end

  local need_swap
  if direction == Direction.left then
    need_swap = 'right'
  elseif direction == Direction.up then
    need_swap = 'down'
  end

  local data, code = herdr_exec_json({
    'pane',
    'split',
    '--direction',
    split_direction,
    '--current',
    '--focus',
  })
  if code ~= 0 then
    return false
  end

  if data == nil or data.result == nil or data.result.pane == nil or data.result.pane.pane_id == nil then
    return false
  end

  if need_swap == nil then
    return true
  end

  local swap_data, swap_code = herdr_exec_json({
    'pane',
    'swap',
    '--direction',
    need_swap,
    '--current',
  })

  return swap_code == 0 and swap_data ~= nil and swap_data.result ~= nil and swap_data.result.swap ~= nil
end

function M.update_mux_layout_details()
  -- Not implemented yet.
end

return M
