local function handler(direction)
  return function(args)
    local amount
    if args and args.args and #args.args > 0 then
      amount = args.args
    end

    require('smart-resize')['resize_' .. direction](amount)
  end
end

vim.api.nvim_add_user_command('SmartResizeLeft', handler('left'), { desc = '"Smart" resize left', nargs = '*' })

vim.api.nvim_add_user_command('SmartResizeRight', handler('right'), { desc = '"Smart" resize right', nargs = '*' })

vim.api.nvim_add_user_command('SmartResizeUp', handler('up'), { desc = '"Smart" resize up', nargs = '*' })

vim.api.nvim_add_user_command('SmartResizeDown', handler('down'), { desc = '"Smart" resize down', nargs = '*' })
