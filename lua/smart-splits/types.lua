---Types and constants shared across more than one module. Anything belonging to
---a single facet lives with that facet: per-call options next to the function
---that takes them, the backend protocol in `backend.lua`, configuration classes
---in `config.lua`.

---@alias SmartSplitsDirection 'left'|'right'|'up'|'down'

---`config.move.at_edge`. Stored by `config.lua`, interpreted by `move.lua`.
---@alias SmartSplitsAtEdgeBehavior 'split'|'wrap'|'stop'|fun(ctx: SmartSplitsAtEdgeContext)

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
