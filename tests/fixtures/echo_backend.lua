---A minimal backend that records every call and handles nothing. Doubles as the
---worked example in PROTOCOL.md and as a way to watch core's delegation points
---fire in a real editor, via `:SmartSplitsLog`.
--- Used to write tests with.
---@class EchoBackend: SmartSplitsBackend
local M = {
  name = 'echo',
  protocol_version = 3,
}

---Calls core has made, in order. Each entry is `{ op, ... }`.
---@type table[]
M.calls = {}

---@param op string
---@param ... any
local function record(op, ...)
  table.insert(M.calls, { op, ... })
  require('smart-splits.log').debug('echo backend: %s(%s)', op, vim.inspect({ ... }))
end

---Nothing to detect, this backend is always usable.
---@return boolean
function M.detect()
  return true
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsBackendMoveOpts|nil
---@return boolean
function M.move(direction, opts)
  record('move', direction, opts)
  return false
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsBackendResizeOpts|nil
---@return boolean
function M.resize(direction, opts)
  record('resize', direction, opts)
  return false
end

function M.health()
  vim.health.ok('echo backend is loaded, it records calls and handles nothing')
end

---Discard the recorded calls.
function M.clear()
  M.calls = {}
end

return M
