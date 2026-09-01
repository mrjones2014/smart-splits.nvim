local M = {}

---The multiplexer protocol version this release implements. Backends can assert
---against it, see PROTOCOL.md.
M.PROTOCOL_VERSION = require('smart-splits.backend').PROTOCOL_VERSION

---@class (partial) SmartSplitsSetupOpts: SmartSplitsConfig

---Configure the plugin. Optional; without it you get the defaults and no
---multiplexer backend.
---@param opts SmartSplitsSetupOpts|nil
function M.setup(opts)
  require('smart-splits.config').setup(opts)
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsMoveOpts|nil
local function move(direction, opts)
  local ok, err = pcall(require('smart-splits.move').move_cursor, direction, opts)
  if not ok then
    require('smart-splits.log').error('failed to move cursor %s: %s', direction, err)
  end
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsSwapOpts|nil
local function swap(direction, opts)
  local ok, err = pcall(require('smart-splits.swap').swap_bufs, direction, opts)
  if not ok then
    require('smart-splits.log').error('failed to swap buffers %s: %s', direction, err)
  end
end

---Resize the current window to the left, delegating to the multiplexer when the
---window already spans the full width.
---@param amount number|nil defaults to `v:count1 * config.resize.amount`
function M.resize_left(amount)
  require('smart-splits.resize').run('left', amount)
end

---Resize the current window to the right, delegating to the multiplexer when the
---window already spans the full width.
---@param amount number|nil defaults to `v:count1 * config.resize.amount`
function M.resize_right(amount)
  require('smart-splits.resize').run('right', amount)
end

---Resize the current window upwards, delegating to the multiplexer when the
---window already spans the full height.
---@param amount number|nil defaults to `v:count1 * config.resize.amount`
function M.resize_up(amount)
  require('smart-splits.resize').run('up', amount)
end

---Resize the current window downwards, delegating to the multiplexer when the
---window already spans the full height.
---@param amount number|nil defaults to `v:count1 * config.resize.amount`
function M.resize_down(amount)
  require('smart-splits.resize').run('down', amount)
end

---Move the cursor to the window on the left, or to the multiplexer pane there
---when already at the leftmost window.
---@param opts SmartSplitsMoveOpts|nil
function M.move_cursor_left(opts)
  move('left', opts)
end

---Move the cursor to the window on the right, or to the multiplexer pane there
---when already at the rightmost window.
---@param opts SmartSplitsMoveOpts|nil
function M.move_cursor_right(opts)
  move('right', opts)
end

---Move the cursor to the window above, or to the multiplexer pane there when
---already at the topmost window.
---@param opts SmartSplitsMoveOpts|nil
function M.move_cursor_up(opts)
  move('up', opts)
end

---Move the cursor to the window below, or to the multiplexer pane there when
---already at the bottommost window.
---@param opts SmartSplitsMoveOpts|nil
function M.move_cursor_down(opts)
  move('down', opts)
end

---Swap the current buffer with the one in the window to the left.
---@param opts SmartSplitsSwapOpts|nil
function M.swap_buf_left(opts)
  swap('left', opts)
end

---Swap the current buffer with the one in the window to the right.
---@param opts SmartSplitsSwapOpts|nil
function M.swap_buf_right(opts)
  swap('right', opts)
end

---Swap the current buffer with the one in the window above.
---@param opts SmartSplitsSwapOpts|nil
function M.swap_buf_up(opts)
  swap('up', opts)
end

---Swap the current buffer with the one in the window below.
---@param opts SmartSplitsSwapOpts|nil
function M.swap_buf_down(opts)
  swap('down', opts)
end

return M
