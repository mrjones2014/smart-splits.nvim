---@class SmartSplitsWeztermModifiers
---@field move string
---@field resize string

---@class SmartSplitsWeztermConfig
---@field direction_keys string[] Keys to use for movements, not including the modifier key (such as alt or ctrl), in order of left, down, up, right
---@field modifiers SmartSplitsWeztermModifiers Modifier keys to use for movement and resize actions, these should be Wezterm's modifier key strings such as 'META', 'CTRL', etc.

if vim ~= nil then
  return -- this is a Wezterm plugin, not part of the Neovim plugin
end

local wezterm = require('wezterm')

local function is_vim(pane)
  -- this is set by the Neovim plugin on launch, and unset on ExitPre in Neovim
  return pane:get_user_vars().IS_NVIM == 'true'
end

---@type SmartSplitsWeztermConfig
local _smart_splits_wezterm_config = {
  direction_keys = { 'h', 'j', 'k', 'l' },
  modifiers = {
    move = 'CTRL',
    resize = 'META',
  },
}

local direction_keys = {
  h = 'Left',
  j = 'Down',
  k = 'Up',
  l = 'Right',
}

local function split_nav(resize_or_move, key)
  local modifier = resize_or_move == 'resize' and _smart_splits_wezterm_config.modifiers.resize
    or _smart_splits_wezterm_config.modifiers.move
  return {
    key = key,
    mods = modifier,
    action = wezterm.action_callback(function(win, pane)
      if is_vim(pane) then
        -- pass the keys through to vim/nvim
        win:perform_action({
          SendKey = {
            key = key,
            mods = modifier,
          },
        }, pane)
      else
        if resize_or_move == 'resize' then
          win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
        end
      end
    end),
  }
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
  end

  local keymaps = {}
  for _, key in ipairs(_smart_splits_wezterm_config.direction_keys) do
    table.insert(keymaps, split_nav('move', key))
    table.insert(keymaps, split_nav('resize', key))
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
