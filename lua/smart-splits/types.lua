---@class SmartSplitsMultiplexer
---@field current_pane_id fun():number|nil
---@field current_pane_at_edge fun(direction:SmartSplitsDirection):boolean
---@field is_in_session fun():boolean
---@field current_pane_is_zoomed fun():boolean
---@field next_pane fun(direction:SmartSplitsDirection):boolean
---@field resize_pane fun(direction:SmartSplitsDirection, amount:number):boolean
---@field split_pane fun(direction:SmartSplitsDirection,size:number|nil):boolean
---@field type SmartSplitsMultiplexerType
---@field on_init fun()|nil
---@field on_exit fun()|nil
---@field update_mux_layout_details fun():nil

---@alias SmartSplitsDirection 'left'|'right'|'up'|'down'

---@alias SmartSplitsAtEdgeBehavior 'split'|'wrap'|'stop'|function
---
---@alias SmartSplitsFloatWinBehavior 'previous'|'mux'

---@alias SmartSplitsMultiplexerType 'tmux'|'wezterm'|'kitty'|'zellij'

---@class SmartSplitsContext
---@field mux SmartSplitsMultiplexer|nil Multiplexer API, if one is currently in use
---@field direction SmartSplitsDirection Which direction you're moving (also indicates edge your cursor is currently at)
---@field split fun() Utility function to split the window into the current direction

local M = {
  Direction = {
    ---@type SmartSplitsDirection
    left = 'left',
    ---@type SmartSplitsDirection
    right = 'right',
    ---@type SmartSplitsDirection
    up = 'up',
    ---@type SmartSplitsDirection
    down = 'down',
  },
  AtEdgeBehavior = {
    ---@type SmartSplitsAtEdgeBehavior
    split = 'split',
    ---@type SmartSplitsAtEdgeBehavior
    wrap = 'wrap',
    ---@type SmartSplitsAtEdgeBehavior
    stop = 'stop',
  },
  FloatWinBehavior = {
    ---@type SmartSplitsFloatWinBehavior
    previous = 'previous',
    ---@type SmartSplitsFloatWinBehavior
    mux = 'mux',
  },
  Multiplexer = {
    ---@type SmartSplitsMultiplexerType
    tmux = 'tmux',
    ---@type SmartSplitsMultiplexerType
    wezterm = 'wezterm',
    ---@type SmartSplitsMultiplexerType
    kitty = 'kitty',
    ---@type SmartSplitsMultiplexerType
    zellij = 'zellij',
  },
}

return M
