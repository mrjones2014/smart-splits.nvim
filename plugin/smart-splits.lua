if vim.g.loaded_smart_splits then
  return
end
vim.g.loaded_smart_splits = true

if vim.fn.has('nvim-0.11') == 0 then
  vim.notify('smart-splits.nvim requires Neovim 0.11 or newer', vim.log.levels.ERROR)
  return
end

local function command(name, handler, opts)
  vim.api.nvim_create_user_command(name, handler, opts)
end

---@param direction SmartSplitsDirection
local function resize(direction)
  return function(args)
    local amount = tonumber(args.args)
    require('smart-splits')['resize_' .. direction](amount)
  end
end

---@param direction SmartSplitsDirection
local function move(direction)
  return function()
    require('smart-splits')['move_cursor_' .. direction]()
  end
end

---@param direction SmartSplitsDirection
local function swap(direction)
  return function()
    require('smart-splits')['swap_buf_' .. direction]()
  end
end

command('SmartResizeLeft', resize('left'), { desc = 'smart-splits: resize left', nargs = '?' })
command('SmartResizeRight', resize('right'), { desc = 'smart-splits: resize right', nargs = '?' })
command('SmartResizeUp', resize('up'), { desc = 'smart-splits: resize up', nargs = '?' })
command('SmartResizeDown', resize('down'), { desc = 'smart-splits: resize down', nargs = '?' })

command('SmartCursorMoveLeft', move('left'), { desc = 'smart-splits: move cursor left' })
command('SmartCursorMoveRight', move('right'), { desc = 'smart-splits: move cursor right' })
command('SmartCursorMoveUp', move('up'), { desc = 'smart-splits: move cursor up' })
command('SmartCursorMoveDown', move('down'), { desc = 'smart-splits: move cursor down' })

command('SmartSwapLeft', swap('left'), { desc = 'smart-splits: swap buffer left' })
command('SmartSwapRight', swap('right'), { desc = 'smart-splits: swap buffer right' })
command('SmartSwapUp', swap('up'), { desc = 'smart-splits: swap buffer up' })
command('SmartSwapDown', swap('down'), { desc = 'smart-splits: swap buffer down' })

command('SmartSplitsLog', function()
  require('smart-splits.log').open_file()
end, { desc = 'smart-splits: open the log file' })

command('SmartSplitsLogLevel', function(args)
  local Log = require('smart-splits.log')
  local level = vim.trim(args.args)
  if not vim.tbl_contains(Log.levels, level) then
    Log.notify(
      vim.log.levels.ERROR,
      'invalid log level `%s`, expected one of %s',
      level,
      table.concat(Log.levels, ', ')
    )
    return
  end
  require('smart-splits.config').log.level = level
end, {
  desc = 'smart-splits: set the log level',
  nargs = 1,
  complete = function(prefix)
    return vim.tbl_filter(function(level)
      return vim.startswith(level, prefix)
    end, require('smart-splits.log').levels)
  end,
})
