---@alias Direction 'left'|'right'|'up'|'down'

---@class Multiplexer
---@field current_pane_id fun():number|nil
---@field current_pane_at_edge fun(direction:Direction):boolean
---@field is_in_session fun():boolean
---@field current_pane_is_zoomed fun():boolean
---@field next_pane fun(direction:Direction):boolean
---@field resize_pane fun(direction:Direction, amount:number):boolean
