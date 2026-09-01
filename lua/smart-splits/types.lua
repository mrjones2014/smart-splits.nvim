---@alias SmartSplitsDirection 'left'|'right'|'up'|'down'

---@alias SmartSplitsAtEdgeBehavior 'split'|'wrap'|'stop'|fun(ctx: SmartSplitsAtEdgeContext)

---@alias SmartSplitsLogLevel 'trace'|'debug'|'info'|'warn'|'error'

---What core knows about the user's intent for a move, which the backend cannot
---work out for itself. Later protocol versions may add fields, so treat unknown
---ones as ignorable.
---@class SmartSplitsMoveOptions
---@field wrap boolean whether the user asked for wrapping, from `config.move.at_edge`

---A multiplexer backend. Backends live in their own plugins, core ships none.
---Only `name`, `protocol_version`, `detect` and `move` are required. Omit
---`resize` or `split` entirely if the multiplexer cannot do them; core checks
---whether the function is present rather than asking for a capability table.
---@class SmartSplitsBackend
---@field name string human readable name, used in logs and `:checkhealth`
---@field protocol_version number major protocol version this backend implements
---@field detect fun():boolean is this multiplexer usable right now? must be cheap and free of side effects
---@field move fun(direction: SmartSplitsDirection, opts: SmartSplitsMoveOptions):boolean move focus one pane, `true` if handled
---@field resize? fun(direction: SmartSplitsDirection, amount: number):boolean resize the current pane, `true` if handled
---@field split? fun(direction: SmartSplitsDirection):boolean create a new pane, `true` if handled
---@field setup? fun() called once, when the backend is resolved
---@field health? fun() called during `:checkhealth smart-splits`, under a header emitted by core

---@alias SmartSplitsBackendSpec SmartSplitsBackend|string
---@alias SmartSplitsBackendConfig SmartSplitsBackendSpec|SmartSplitsBackendSpec[]|fun():SmartSplitsBackendSpec|SmartSplitsBackendSpec[]

---Passed to `config.move.at_edge` when it is a function.
---@class SmartSplitsAtEdgeContext
---@field backend SmartSplitsBackend|nil the resolved backend, `nil` if none resolved
---@field direction SmartSplitsDirection direction you tried to move, so also the edge you are sitting on
---@field split fun() split the current window towards `direction`
---@field wrap fun() jump to the window on the opposite edge

local M = {}

M.Direction = {
  ---@type SmartSplitsDirection
  left = 'left',
  ---@type SmartSplitsDirection
  right = 'right',
  ---@type SmartSplitsDirection
  up = 'up',
  ---@type SmartSplitsDirection
  down = 'down',
}

M.AtEdgeBehavior = {
  ---@type SmartSplitsAtEdgeBehavior
  split = 'split',
  ---@type SmartSplitsAtEdgeBehavior
  wrap = 'wrap',
  ---@type SmartSplitsAtEdgeBehavior
  stop = 'stop',
}

return M
