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

return {
  -- resize
  { 'SmartResizeLeft', resize_handler('left'), { desc = 'smart-splits: resize left', nargs = '*' } },
  { 'SmartResizeRight', resize_handler('right'), { desc = 'smart-splits: resize right', nargs = '*' } },
  { 'SmartResizeUp', resize_handler('up'), { desc = 'smart-splits: resize up', nargs = '*' } },
  { 'SmartResizeDown', resize_handler('down'), { desc = 'smart-splits: resize down', nargs = '*' } },
  -- move
  { 'SmartCursorMoveLeft', move_handler('left'), { desc = 'smart-splits: move cursor left', nargs = '*' } },
  { 'SmartCursorMoveRight', move_handler('right'), { desc = 'smart-splits: move cursor right', nargs = '*' } },
  { 'SmartCursorMoveUp', require('smart-splits').move_cursor_up, { desc = 'smart-splits: move cursor up' } },
  { 'SmartCursorMoveDown', require('smart-splits').move_cursor_down, { desc = 'smart-splits: move cursor down' } },
  -- resize mode
  {
    'SmartResizeMode',
    require('smart-splits').start_resize_mode,
    { desc = 'smart-splits: Start persistent resize mode, press <ESC> to exit resize mode' },
  },
}
