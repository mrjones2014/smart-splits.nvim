local M = {}

----------
-- CONFIG
----------

M.config = {
  ignored_buftypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  ignored_filetypes = {
    'NvimTree',
  },
  move_cursor_same_row = false,
}

function M.setup(config)
  M.config.ignored_buftypes = config.ignored_buftypes or M.config.ignored_buftypes
  M.config.ignored_filetypes = config.ignored_filetypes or M.config.ignored_filetypes
  if config.move_cursor_same_row ~= nil then
    M.config.move_cursor_same_row = config.move_cursor_same_row
  end
end

----------
-- PLUGIN
----------

vim.tbl_map(function(direction)
  local resize_key = string.format('resize_%s', direction)
  local move_key = string.format('move_cursor_%s', direction)
  M[resize_key] = require('smart-splits')[resize_key]
  M[move_key] = require('smart-splits')[move_key]
end)

M.start_resize_mode = require('smart-splits.resize-mode').start_resize_mode

return M
