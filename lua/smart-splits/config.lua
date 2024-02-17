local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local types = require('smart-splits.types')
local AtEdgeBehavior = types.AtEdgeBehavior
local Multiplexer = types.Multiplexer
local utils = require('smart-splits.utils')
local mux_utils = require('smart-splits.mux.utils')

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
---@field set_default_multiplexer fun():string|nil
---@field log_level 'trace'|'debug'|'info'|'warn'|'error'|'fatal'

---@type SmartSplitsConfig
local config = { ---@diagnostic disable-line:missing-fields
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
  log_level = 'info',
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

  -- if running in a GUI instead of terminal TUI, disable mux
  -- because you aren't in any terminal, you're in a Neovim GUI
  if mux_utils.are_we_gui() then
    config.multiplexer_integration = false
    return nil
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  if term == 'tmux' then
    config.multiplexer_integration = Multiplexer.tmux
  elseif term == 'wezterm' then
    config.multiplexer_integration = Multiplexer.wezterm
  elseif vim.env.KITTY_LISTEN_ON ~= nil then
    -- Kitty doesn't use $TERM_PROGRAM, and also requires remote control enabled anyway
    config.multiplexer_integration = Multiplexer.kitty
  end

  if type(config.multiplexer_integration) == 'string' then
    log.debug('Auto-detected multiplexer back-end: %s', config.multiplexer_integration)
  else
    log.debug('Auto-detected multiplexer back-end: none')
  end

  return type(config.multiplexer_integration) == 'string' and config.multiplexer_integration or nil
end

function M.setup(new_config)
  config = vim.tbl_deep_extend('force', config, new_config or {})

  -- check deprecated settings
  ---@diagnostic disable:undefined-field

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
  ---@diagnostic enable:undefined-field
end

return M
