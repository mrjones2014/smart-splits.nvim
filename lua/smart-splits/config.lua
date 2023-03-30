local config = {
  ignored_buftypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  ignored_filetypes = {
    'NvimTree',
  },
  default_amount = 3,
  wrap_at_edge = true,
  move_cursor_same_row = false,
  cursor_follows_swapped_bufs = false,
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
  multiplexer_integration = nil,
  disable_multiplexer_nav_when_zoomed = true,
}

local M = setmetatable({}, {
  __index = function(_, key)
    return config[key]
  end,
  __newindex = function(_, key, value)
    config[key] = value
  end,
})

function M.setup(new_config)
  config = vim.tbl_deep_extend('force', config, new_config or {})

  if config.tmux_integration then
    vim.deprecate('config.tmux_integration = true', "config.multiplexer_integration = 'tmux'", 'smart-splits.nvim')
    config.multiplexer_integration = 'tmux'
  elseif config.tmux_integration == false then
    config.multiplexer_integration = false
  end

  if config.disable_tmux_nav_when_zoomed then
    vim.deprecate(
      'config.disable_tmux_nav_when_zoomed = true',
      'config.disable_multiplexer_nav_when_zoomed = true',
      'smart-splits.nvim'
    )
    config.disable_multiplexer_nav_when_zoomed = true
  end

  -- unless explicitly disabled, try to determine it automatically
  if config.multiplexer_integration ~= false then
    if vim.env.TMUX ~= nil then
      config.multiplexer_integration = 'tmux'
    elseif vim.env.WEZTERM_PANE ~= nil then
      config.multiplexer_integration = 'wezterm'
    end
  end
end

return M
