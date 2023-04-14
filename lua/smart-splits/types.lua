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
    left = 'left',
    right = 'right',
    up = 'up',
    down = 'down',
  },
  AtEdgeBehavior = {
    split = 'split',
    wrap = 'wrap',
    stop = 'stop',
  },
  Multiplexer = {
    tmux = 'tmux',
    wezterm = 'wezterm',
    kitty = 'kitty',
  },
}

return M
