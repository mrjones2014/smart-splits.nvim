local types = require('smart-splits.types')
local AtEdgeBehavior = types.AtEdgeBehavior
local Multiplexer = types.Multiplexer

---@class SmartResizeModeHooks
---@field on_enter fun()|nil
---@field on_leave fun()|nil

---@class SmartResizeModeConfig
---@field quit_key string
---@field resize_keys string[]
---@field silent boolean
---@field hooks SmartResizeModeHooks

---@class SmartSplitsConfig
---@field ignored_buftypes string[]
---@field ignored_filetypes string[]
---@field default_amount number
---@field at_edge SmartSplitsAtEdgeBehavior
---@field move_cursor_same_row boolean
---@field cursor_follows_swapped_bufs boolean
---@field resize_mode SmartResizeModeConfig
---@field ignored_events string[]
---@field multiplexer_integration SmartSplitsMultiplexerType|false
---@field disable_multiplexer_nav_when_zoomed boolean
---@field kitty_password string|nil
---@field setup fun(cfg:table)
---@field set_default_multiplexer fun()

---@type SmartSplitsConfig
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
  at_edge = AtEdgeBehavior.wrap,
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
  multiplexer_integration = nil, ---@diagnostic disable-line this gets computed during startup unless disabled by user
  disable_multiplexer_nav_when_zoomed = true,
  kitty_password = nil,
}

---@type SmartSplitsConfig
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
    config.multiplexer_integration = Multiplexer.tmux
  elseif vim.env.TERM_PROGRAM == 'WezTerm' then
    config.multiplexer_integration = Multiplexer.wezterm
    -- Kitty doesn't use $TERM_PROGRAM, and also requires remote control enabled anyway
  elseif vim.env.KITTY_LISTEN_ON ~= nil then
    config.multiplexer_integration = Multiplexer.kitty
  end
end

function M.setup(new_config)
  config = vim.tbl_deep_extend('force', config, new_config or {})

  -- check deprecated settings

  if config.tmux_integration then
    vim.deprecate(
      'config.tmux_integration = true',
      "config.multiplexer_integration = 'tmux'|'wezterm'|'kitty'",
      'smart-splits.nvim'
    )
    config.multiplexer_integration = Multiplexer.tmux
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

  if config.wrap_at_edge == false or config.wrap_at_edge == true then
    config.at_edge = config.wrap_at_edge == true and AtEdgeBehavior.wrap or AtEdgeBehavior.stop
    vim.deprecate('config.wrap_at_edge', "config.at_edge = 'wrap'|'split'|'stop'", 'smart-splits.nvim')
  end
end

return M
