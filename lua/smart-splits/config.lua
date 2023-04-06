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

function M.set_default_multiplexer()
  -- if explicitly disabled or set to a different value, don't do anything
  if config.multiplexer_integration == false and config.multiplexer_integration ~= nil then
    return
  end

  if vim.env.TERM_PROGRAM == 'tmux' then
    config.multiplexer_integration = 'tmux'
  elseif vim.env.TERM_PROGRAM == 'WezTerm' then
    config.multiplexer_integration = 'wezterm'
    -- Kitty doesn't use $TERM_PROGRAM
  elseif vim.env.KITTY_LISTEN_ON ~= nil then
    config.multiplexer_integration = 'kitty'
  end
end

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
end

return M
