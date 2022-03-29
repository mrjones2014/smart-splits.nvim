local M = {
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
  M.ignored_buftypes = config.ignored_buftypes or M.ignored_buftypes
  M.ignored_filetypes = config.ignored_filetypes or M.ignored_filetypes
  if config.move_cursor_same_row ~= nil then
    M.move_cursor_same_row = config.move_cursor_same_row
  end
end

return M
