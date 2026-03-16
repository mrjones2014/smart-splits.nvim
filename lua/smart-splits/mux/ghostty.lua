local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local utils = lazy.require_on_exported_call('smart-splits.utils')

--- Execute an AppleScript snippet synchronously and return trimmed stdout.
--- Returns empty string on failure.
---@param script string
---@return string
local function osascript_str(script)
  local out, _ = utils.system({ 'osascript', '-e', script })
  return vim.trim(out or '')
end

--- Build an AppleScript snippet that performs a Ghostty action on the focused terminal.
---@param action string Ghostty action string e.g. "goto_split:left"
---@return string
local function action_script(action)
  return string.format(
    'tell application "Ghostty"\n'
      .. '  set t to focused terminal of selected tab of front window\n'
      .. '  return perform action "%s" on t\n'
      .. 'end tell',
    action
  )
end

---@type SmartSplitsMultiplexer
local M = {}

M.type = 'ghostty'

function M.is_in_session()
  -- Ghostty sets TERM_PROGRAM=ghostty in every terminal it spawns.
  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'ghostty'
end

function M.current_pane_id()
  -- Return the UUID of the currently focused Ghostty terminal (split).
  -- This is used by mux/init.lua to detect whether next_pane() actually moved focus.
  local id = osascript_str(
    'tell application "Ghostty"\n'
      .. '  return id of (focused terminal of selected tab of front window) as string\n'
      .. 'end tell'
  )
  if id == '' then
    log.debug('ghostty: failed to get current pane id')
    return nil
  end
  log.trace('ghostty: current_pane_id = %s', id)
  return id
end

function M.current_pane_at_edge()
  -- Ghostty does not expose split layout topology via AppleScript, so edge
  -- position cannot be queried directly. Return false and let mux/init.lua's
  -- pane-ID comparison fallback detect when a move had no effect.
  return false
end

function M.current_pane_is_zoomed()
  -- Ghostty supports toggle_split_zoom but does not expose zoom state via
  -- AppleScript properties. Return false conservatively.
  return false
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end

  -- The recommended Ghostty integration uses `performable:` keybinds in the
  -- Ghostty config (e.g. `keybind = performable:ctrl+h=goto_split:left`).
  -- With that setup, Ghostty consumes the key and moves between Ghostty splits
  -- itself when the action is performable; otherwise the key passes through to
  -- Neovim for internal window navigation. next_pane() is therefore typically
  -- not invoked during normal use, but is retained as an AppleScript fallback
  -- for programmatic split control (e.g. smart-splits swap_buf).
  --
  -- perform action "goto_split:<direction>" returns true on success, or the
  -- terminal's UUID string when no split exists in that direction.
  local result = osascript_str(action_script('goto_split:' .. direction))
  log.trace('ghostty: goto_split:%s result = %s', direction, result)
  return result == 'true'
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end

  local action = string.format('resize_split:%s,%s', direction, tostring(amount))
  local result = osascript_str(action_script(action))
  log.trace('ghostty: %s result = %s', action, result)
  return result == 'true'
end

function M.split_pane(direction, _)
  if not M.is_in_session() then
    return false
  end

  local action = string.format('new_split:%s', direction)
  local result = osascript_str(action_script(action))
  log.trace('ghostty: %s result = %s', action, result)
  return result == 'true'
end

-- on_init / on_exit: The recommended Ghostty integration relies on
-- `performable:` keybinds in the Ghostty config rather than a runtime marker
-- written by Neovim. Ghostty natively handles the "is this action possible
-- right now?" check, making these no-ops. See next_pane() above for details.
function M.on_init() end
function M.on_exit() end

function M.update_mux_layout_details()
  -- No layout query API in Ghostty; edge detection falls back to pane-ID
  -- comparison in mux/init.lua (move_multiplexer_inner).
end

return M
