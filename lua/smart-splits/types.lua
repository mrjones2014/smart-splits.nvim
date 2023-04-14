---@class Multiplexer
---@field current_pane_id fun():number|nil
---@field current_pane_at_edge fun(direction:Direction):boolean
---@field is_in_session fun():boolean
---@field current_pane_is_zoomed fun():boolean
---@field next_pane fun(direction:Direction):boolean
---@field resize_pane fun(direction:Direction, amount:number):boolean

---@alias Direction 'left'|'right'|'up'|'down'

---@alias AtEdgeBehavior 'split'|'wrap'|'stop'

---@alias MultiplexerType 'tmux'|'wezterm'|'kitty'

local M = {
  Direction = {
    ---@type Direction
    left = 'left',
    ---@type Direction
    right = 'right',
    ---@type Direction
    up = 'up',
    ---@type Direction
    down = 'down',
  },
  AtEdgeBehavior = {
    ---@type AtEdgeBehavior
    split = 'split',
    ---@type AtEdgeBehavior
    wrap = 'wrap',
    ---@type AtEdgeBehavior
    stop = 'stop',
  },
  Multiplexer = {
    ---@type MultiplexerType
    tmux = 'tmux',
    ---@type MultiplexerType
    wezterm = 'wezterm',
    ---@type MultiplexerType
    kitty = 'kitty',
  },
}

return M
