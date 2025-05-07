local Direction = require('smart-splits.types').Direction

local function resize_handler(direction)
  return function(args)
    local amount
    if args and args.args and #args.args > 0 then
      amount = args.args
    end

    require('smart-splits')['resize_' .. direction](amount)
  end
end

local function move_handler(direction)
  return function(args)
    local same_row
    if args and args.args and #args.args > 0 then
      same_row = args.args
    end
    require('smart-splits')['move_cursor_' .. direction](same_row)
  end
end

local function swap_handler(direction)
  return function(args)
    local same_row
    if args and args.args and #args.args > 0 then
      same_row = args.args
    end
    require('smart-splits')['swap_buf_' .. direction](same_row)
  end
end

return {
  -- resize
  { 'SmartResizeLeft', resize_handler(Direction.left), { desc = 'smart-splits: resize left', nargs = '*' } },
  { 'SmartResizeRight', resize_handler(Direction.right), { desc = 'smart-splits: resize right', nargs = '*' } },
  { 'SmartResizeUp', resize_handler(Direction.up), { desc = 'smart-splits: resize up', nargs = '*' } },
  { 'SmartResizeDown', resize_handler(Direction.down), { desc = 'smart-splits: resize down', nargs = '*' } },
  -- move
  { 'SmartCursorMoveLeft', move_handler(Direction.left), { desc = 'smart-splits: move cursor left', nargs = '*' } },
  { 'SmartCursorMoveRight', move_handler(Direction.right), { desc = 'smart-splits: move cursor right', nargs = '*' } },
  -- same_row does not apply to up/down
  { 'SmartCursorMoveUp', require('smart-splits').move_cursor_up, { desc = 'smart-splits: move cursor up' } },
  { 'SmartCursorMoveDown', require('smart-splits').move_cursor_down, { desc = 'smart-splits: move cursor down' } },
  -- swap
  { 'SmartSwapLeft', swap_handler(Direction.left), { desc = 'smart-splits: swap buffer left', nargs = '*' } },
  { 'SmartSwapRight', swap_handler(Direction.right), { desc = 'smart-splits: swap buffer right', nargs = '*' } },
  -- same_row does not apply to up/down
  { 'SmartSwapUp', require('smart-splits').swap_buf_up, { desc = 'smart-splits: swap buffer up' } },
  { 'SmartSwapDown', require('smart-splits').swap_buf_down, { desc = 'smart-splits: swap buffer down' } },
  {
    'SmartSplitsLog',
    function()
      require('smart-splits.log').open_log_file()
    end,
    { desc = 'smart-splits: show log file' },
  },
  {
    'SmartSplitsLogLevel',
    function(args)
      local log_level = vim.tbl_get(args, 'fargs', 1)
      if not vim.tbl_contains(require('smart-splits.log').levels, log_level) then
        error(string.format('Invalid log level %s', log_level))
        return
      end
      require('smart-splits.config').log_level = log_level
    end,
    { desc = 'smart-splits: set the log level to use for logging', nargs = 1 },
  },
}
