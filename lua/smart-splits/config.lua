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
    resize_keys = { 'h', 'j', 'k', 'l' },
    silent = false,
    hooks = {
      on_enter = nil,
      on_leave = nil,
    },
  },
  ignored_events = {
    'BufEnter',
    'WinEnter',
  },
  tmux_integration = false,
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

local function default_resize_keys(new_config)
  if type(new_config) ~= 'table' or #new_config ~= 4 then
    return M.resize_mode.resize_keys
  end

  return new_config
end

local function default_resize_mode(new_config)
  if not new_config then
    return M.resize_mode
  end
  return {
    quit_key = new_config.quit_key or M.resize_mode.quit_key,
    resize_keys = default_resize_keys(vim.tbl_get(new_config, 'resize_keys')),
    silent = default_bool(new_config.silent, M.resize_mode.silent),
    hooks = default_hooks(new_config.hooks),
  }
end

function M.setup(config)
  M.ignored_buftypes = config.ignored_buftypes or M.ignored_buftypes
  M.ignored_filetypes = config.ignored_filetypes or M.ignored_filetypes
  M.move_cursor_same_row = default_bool(config.move_cursor_same_row, M.move_cursor_same_row)
  M.resize_mode = default_resize_mode(config.resize_mode)
  M.tmux_integration = default_bool(config.tmux_integration, M.tmux_integration)
end

return M
