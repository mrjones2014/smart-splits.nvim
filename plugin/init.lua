---@class SmartSplitsWeztermModifierMap
---@field wezterm string
---@field neovim string

---@class SmartSplitsWeztermModifiers
---@field move string | SmartSplitsWeztermModifierMap
---@field resize string | SmartSplitsWeztermModifierMap

---@class DirectionKeys
---@field move string[] keys to use for moving windows
---@field resize string[] keys to use for resizing windows

---@class SmartSplitsWeztermConfig
---@field default_amount number The number of cells to resize by
---@field direction_keys string[]|DirectionKeys Keys to use for movements, not including the modifier key (such as alt or ctrl), in order of left, down, up, right
---@field modifiers SmartSplitsWeztermModifiers Modifier keys to use for movement and resize actions, these should be Wezterm's modifier key strings such as 'META', 'CTRL', etc.
---@field log_level 'info'|'warn'|'error'

if vim ~= nil then
  return -- this is a Wezterm plugin, not part of the Neovim plugin
end

local wezterm = require('wezterm')

---@type SmartSplitsWeztermConfig
local _smart_splits_wezterm_config = {
  default_amount = 3,
  direction_keys = { 'h', 'j', 'k', 'l' },
  modifiers = {
    move = 'CTRL',
    resize = 'META',
  },
  log_level = 'info',
}

local logger = {
  info = function(...)
    if _smart_splits_wezterm_config.log_level == 'info' then
      wezterm.log_info(...)
    end
  end,
  warn = function(...)
    if
      _smart_splits_wezterm_config.log_level == 'info' --
      or _smart_splits_wezterm_config.log_level == 'warn'
    then
      wezterm.log_warn(...)
    end
  end,
  error = function(...)
    if
      _smart_splits_wezterm_config.log_level == 'info'
      or _smart_splits_wezterm_config.log_level == 'warn'
      or _smart_splits_wezterm_config.log_level == 'error'
    then
      wezterm.log_error(...)
    end
  end,
}

local function is_vim(pane)
  -- if type is PaneInformation
  if pane.user_vars ~= nil then
    logger.info('[smart-splits.nvim]: PaneInformation.user_vars.IS_NVIM = ', pane.user_vars.IS_NVIM)
    return pane.user_vars.IS_NVIM == 'true'
  end

  -- this is set by the Neovim plugin on launch, and unset on ExitPre in Neovim
  logger.info('[smart-splits.nvim]: Pane:get_user_vars().IS_NVIM = ', pane:get_user_vars().IS_NVIM)
  return pane:get_user_vars().IS_NVIM == 'true'
end

local Directions = { 'Left', 'Down', 'Up', 'Right' }

---@param resize_or_move 'resize'|'move'
---@param key string
---@param direction 'Left'|'Down'|'Up'|'Right'
---@return table
local function split_nav(resize_or_move, key, direction)
  local modifier = resize_or_move == 'resize' and _smart_splits_wezterm_config.modifiers.resize
    or _smart_splits_wezterm_config.modifiers.move
  local wezterm_modifier = type(modifier) == 'table' and modifier.wezterm or modifier
  local neovim_modifier = type(modifier) == 'table' and modifier.neovim or modifier
  return {
    key = key,
    mods = wezterm_modifier,
    action = wezterm.action_callback(function(win, pane)
      local num_panes = #win:active_tab():panes()
      if is_vim(pane) or num_panes == 1 then
        -- pass the keys through to vim/nvim
        win:perform_action({
          SendKey = {
            key = key,
            mods = neovim_modifier,
          },
        }, pane)
      else
        if resize_or_move == 'resize' then
          win:perform_action({ AdjustPaneSize = { direction, _smart_splits_wezterm_config.default_amount } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction }, pane)
        end
      end
    end),
  }
end

---@return string[]
local function get_move_direction_keys()
  -- check if table format or list format
  if _smart_splits_wezterm_config.direction_keys.move ~= nil then
    return _smart_splits_wezterm_config.direction_keys.move
  end

  return _smart_splits_wezterm_config.direction_keys --[[@as string[] ]]
end

---@return string[]
local function get_resize_direction_keys()
  -- check if table format or list format
  if _smart_splits_wezterm_config.direction_keys.resize ~= nil then
    return _smart_splits_wezterm_config.direction_keys.resize
  end

  return _smart_splits_wezterm_config.direction_keys --[[@as string[] ]]
end

---Apply plugin to Wezterm config.
---@param config_builder table
---@param plugin_config SmartSplitsWeztermConfig|nil
---@return table config_builder the updated config
local function apply_to_config(config_builder, plugin_config)
  -- apply plugin config
  if plugin_config then
    _smart_splits_wezterm_config.direction_keys = plugin_config.direction_keys
      or _smart_splits_wezterm_config.direction_keys
    if plugin_config.modifiers then
      _smart_splits_wezterm_config.modifiers.move = plugin_config.modifiers.move
        or _smart_splits_wezterm_config.modifiers.move
      _smart_splits_wezterm_config.modifiers.resize = plugin_config.modifiers.resize
        or _smart_splits_wezterm_config.modifiers.resize
    end
    if plugin_config.default_amount then
      _smart_splits_wezterm_config.default_amount = plugin_config.default_amount
        or _smart_splits_wezterm_config.default_amount
    end
    if plugin_config.log_level then
      _smart_splits_wezterm_config.log_level = plugin_config.log_level
    end
  end

  local keymaps = {}
  for idx, key in ipairs(get_move_direction_keys()) do
    table.insert(keymaps, split_nav('move', key, Directions[idx]))
  end
  for idx, key in ipairs(get_resize_direction_keys()) do
    table.insert(keymaps, split_nav('resize', key, Directions[idx]))
  end

  if config_builder.keys == nil then
    config_builder.keys = keymaps
  else
    for _, keymap in ipairs(keymaps) do
      table.insert(config_builder.keys, keymap)
    end
  end
  return config_builder
end

return {
  apply_to_config = apply_to_config,
  is_vim = is_vim,
}
