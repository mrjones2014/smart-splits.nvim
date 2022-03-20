local function resize_handler(direction)
  return function(args)
    local amount
    if args and args.args and #args.args > 0 then
      amount = args.args
    end

    require('smart-resize')['resize_' .. direction](amount)
  end
end

-- resizing
vim.api.nvim_add_user_command('SmartResizeLeft', resize_handler('left'), { desc = '"Smart" resize left', nargs = '*' })
vim.api.nvim_add_user_command(
  'SmartResizeRight',
  resize_handler('right'),
  { desc = '"Smart" resize right', nargs = '*' }
)
vim.api.nvim_add_user_command('SmartResizeUp', resize_handler('up'), { desc = '"Smart" resize up', nargs = '*' })
vim.api.nvim_add_user_command('SmartResizeDown', resize_handler('down'), { desc = '"Smart" resize down', nargs = '*' })

-- movements
vim.api.nvim_add_user_command(
  'SmartCursorMoveLeft',
  require('smart-resize').move_cursor_left,
  { desc = '"Smart" resize left' }
)
vim.api.nvim_add_user_command(
  'SmartCursorMoveRight',
  require('smart-resize').move_cursor_right,
  { desc = '"Smart" resize right' }
)
vim.api.nvim_add_user_command(
  'SmartCursorMoveUp',
  require('smart-resize').move_cursor_up,
  { desc = '"Smart" resize up' }
)
vim.api.nvim_add_user_command(
  'SmartCursorMoveDown',
  require('smart-resize').move_cursor_down,
  { desc = '"Smart" resize down' }
)
