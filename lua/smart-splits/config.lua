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
  resize_mode = {
    quit_key = '<ESC>',
    silent = false,
    hooks = {
      on_enter = nil,
      on_leave = nil,
    },
  },
}

local function default_bool(value, default)
  if value == nil then
    return default
  end
  return value
end

local function default_hooks(new_config)
  if not new_config then
    return M.resize_mode.hooks
  end
  return {
    on_enter = new_config.on_enter or M.resize_mode.hooks.on_enter,
    on_leave = new_config.on_leave or M.resize_mode.hooks.on_leave,
  }
end

local function default_resize_mode(new_config)
  if not new_config then
    return M.resize_mode
  end
  return {
    quit_key = new_config.quit_key or M.resize_mode.quit_key,
    silent = default_bool(new_config.silent, M.resize_mode.silent),
    hooks = default_hooks(new_config.hooks),
  }
end

function M.setup(config)
  M.ignored_buftypes = config.ignored_buftypes or M.ignored_buftypes
  M.ignored_filetypes = config.ignored_filetypes or M.ignored_filetypes
  M.move_cursor_same_row = default_bool(config.move_cursor_same_row, M.move_cursor_same_row)
  M.resize_mode = default_resize_mode(config.resize_mode)

  -- TODO: Remove this code block in the next commits
  if config.resize_mode_quit_key then
    M.resize_mode.quit_key = config.resize_mode_quit_key
    local msg = 'smart-splits: resize_mode_quit_key has been changed to resize_mode.quit_key,\n'
      .. 'please update your config. See README.md for details.'
    vim.notify(msg, vim.log.levels.WARN)
  end
  if config.resize_mode_silent then
    M.resize_mode.silent = config.resize_mode_silent
    local msg = 'smart-splits: resize_mode_silent has been changed to resize_mode.silent,\n'
      .. 'please update your config. See README.md for details.'
    vim.notify(msg, vim.log.levels.WARN)
  end
end

return M
