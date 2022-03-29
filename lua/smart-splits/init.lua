local M = {}

function M.setup(config)
  require('smart-splits.config').setup(config)
end

vim.tbl_map(function(direction)
  local resize_key = string.format('resize_%s', direction)
  local move_key = string.format('move_cursor_%s', direction)
  M[resize_key] = require('smart-splits.api')[resize_key]
  M[move_key] = require('smart-splits.api')[move_key]
end, {
  'left',
  'right',
  'up',
  'down',
})

M.start_resize_mode = require('smart-splits.resize-mode').start_resize_mode

return M
