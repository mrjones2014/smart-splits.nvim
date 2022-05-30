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
  resize_mode_quit_key = '<ESC>',
  resize_mode_silent = false,
}

local function default_bool(value, default)
  if value == nil then
    return default
  else
    return value
  end
end

function M.setup(config)
  M.ignored_buftypes = config.ignored_buftypes or M.ignored_buftypes
  M.ignored_filetypes = config.ignored_filetypes or M.ignored_filetypes
  M.move_cursor_same_row = default_bool(config.move_cursor_same_row, M.move_cursor_same_row)
  M.resize_mode_quit_key = config.resize_mode_quit_key or M.resize_mode_quit_key
  M.resize_mode_silent = default_bool(config.resize_mode_silent, M.resize_mode_silent)
end

return M
