local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local types = require('smart-splits.types')
local AtEdgeBehavior = types.AtEdgeBehavior
local FloatWinBehavior = types.FloatWinBehavior
local Multiplexer = types.Multiplexer
local mux_utils = require('smart-splits.mux.utils')

---@class SmartResizeModeConfig
---@field quit_key string
---@field resize_keys string[]
---@field silent boolean

---@class SmartSplitsConfig
---@field ignored_buftypes string[]
---@field ignored_filetypes string[]
---@field default_amount number
---@field at_edge SmartSplitsAtEdgeBehavior
---@field float_win_behavior SmartSplitsFloatWinBehavior
---@field move_cursor_same_row boolean
---@field cursor_follows_swapped_bufs boolean
---@field ignored_events string[]
---@field multiplexer_integration SmartSplitsMultiplexerType|false
---@field disable_multiplexer_nav_when_zoomed boolean
---@field wezterm_cli_path string|nil
---@field kitty_password string|nil
---@field zellij_move_focus_or_tab boolean
---@field setup fun(cfg:table)
---@field set_default_multiplexer fun():string|nil
---@field log_level 'trace'|'debug'|'info'|'warn'|'error'|'fatal'

---@type SmartSplitsConfig
local config = { ---@diagnostic disable-line:missing-fields
  wezterm_cli_path = mux_utils.is_WSL() and 'wezterm.exe' or 'wezterm',
  ignored_buftypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  ignored_filetypes = {
    'NvimTree',
  },
  default_amount = 3,
  at_edge = mux_utils.are_we_kitty() and AtEdgeBehavior.stop or AtEdgeBehavior.wrap,
  float_win_behavior = FloatWinBehavior.previous,
  move_cursor_same_row = false,
  cursor_follows_swapped_bufs = false,
  ignored_events = {
    'BufEnter',
    'WinEnter',
  },
  multiplexer_integration = nil, ---@diagnostic disable-line this gets computed during startup unless disabled by user
  disable_multiplexer_nav_when_zoomed = true,
  kitty_password = nil,
  zellij_move_focus_or_tab = false,
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
  -- if running in a GUI instead of terminal TUI, disable mux
  -- because you aren't in any terminal, you're in a Neovim GUI
  if mux_utils.are_we_gui() then
    log.debug('Disabling multiplexer_integration because nvim is running in a GUI, not a TTY')
    config.multiplexer_integration = false
    return
  end

  -- for lazy environments, allow users to specify the mux before the plugin
  -- is loaded by using a `vim.g` variable
  if vim.g.smart_splits_multiplexer_integration ~= nil then
    log.debug(
      'Taking multiplexer_integration from vim.g.multiplexer_integration: %s',
      vim.g.smart_splits_multiplexer_integration
    )
    config.multiplexer_integration = vim.g.smart_splits_multiplexer_integration
    -- if set to 0 or 1, convert to boolean
    if type(config.multiplexer_integration) == 'number' then
      config.multiplexer_integration = config.multiplexer_integration ~= 0
    end
    return
  end

  -- if explicitly disabled or set to a different value, don't do anything
  if config.multiplexer_integration == false or config.multiplexer_integration ~= nil then
    return
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  if term == 'tmux' then
    config.multiplexer_integration = Multiplexer.tmux
  elseif vim.env.ZELLIJ ~= nil then
    config.multiplexer_integration = 'zellij'
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
end

function M.setup(new_config)
  local original_mux = config.multiplexer_integration

  config = vim.tbl_deep_extend('force', config, new_config or {})
  -- if the mux setting changed, run startup again
  if
    original_mux ~= nil
    and original_mux ~= false
    and #tostring(original_mux or '') == 0
    and original_mux ~= config.multiplexer_integration
  then
    mux_utils.startup()
  end

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
