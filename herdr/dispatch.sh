#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
direction="${2:-}"

case "$mode:$direction" in
  move:left | move:down | move:up | move:right) ;;
  resize:left | resize:down | resize:up | resize:right) ;;
  *)
    echo "usage: dispatch.sh move|resize left|down|up|right" >&2
    exit 2
    ;;
esac

herdr_bin="${HERDR_BIN_PATH:-herdr}"
pane_id="${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}"

# Fallback: extract focused_pane_id from the plugin context JSON
# using only sed, avoiding any external language dependency.
if [ -z "$pane_id" ] && [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
  pane_id="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" \
    | sed -n 's/.*"focused_pane_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)"
fi

if [ -z "$pane_id" ]; then
  echo "smart-splits herdr plugin: focused pane id is unavailable" >&2
  exit 1
fi

marker_dir() {
  printf '%s/smart-splits.nvim/herdr-panes\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

marker_path() {
  printf '%s/%s\n' "$(marker_dir)" "$1"
}

marker_value() {
  local pane="$1"
  local key="$2"
  local path
  path="$(marker_path "$pane")"
  while IFS= read -r line; do
    case "$line" in
      "$key"=*)
        printf '%s\n' "${line#*=}"
        return 0
        ;;
    esac
  done <"$path"
  return 1
}

is_nvim_pane() {
  local pane="$1"
  local path
  path="$(marker_path "$pane")"
  [ -f "$path" ] || return 1

  # Check that the marker's PID is still alive, so stale markers
  # from crashed Neovim sessions are ignored.
  local pid
  pid="$(marker_value "$pane" pid 2>/dev/null || true)"
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  return 0
}

nvim_command_for() {
  case "$mode:$direction" in
    resize:left) echo 'SmartResizeLeft' ;;
    resize:down) echo 'SmartResizeDown' ;;
    resize:up) echo 'SmartResizeUp' ;;
    resize:right) echo 'SmartResizeRight' ;;
    move:left) echo 'SmartCursorMoveLeft' ;;
    move:down) echo 'SmartCursorMoveDown' ;;
    move:up) echo 'SmartCursorMoveUp' ;;
    move:right) echo 'SmartCursorMoveRight' ;;
  esac
}

invoke_nvim_command() {
  local pane="$1"
  local command="$2"
  local server nvim_bin

  server="$(marker_value "$pane" server 2>/dev/null || true)"
  if [ -z "$server" ]; then
    echo "smart-splits herdr plugin: Neovim pane marker has no RPC server" >&2
    return 1
  fi

  nvim_bin="$(marker_value "$pane" nvim 2>/dev/null || true)"
  if [ -z "$nvim_bin" ]; then
    nvim_bin="${NVIM_BIN:-nvim}"
  fi

  "$nvim_bin" --server "$server" --remote-send "<Cmd>${command}<CR>"
}

# Load user config from the per-plugin config directory.
config_file="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/smart-splits.nvim}/config.sh"
if [ -f "$config_file" ]; then
  # shellcheck source=/dev/null
  . "$config_file"
fi

if is_nvim_pane "$pane_id"; then
  invoke_nvim_command "$pane_id" "$(nvim_command_for)"
  exit 0
fi

if [ "$mode" = "resize" ]; then
  amount="${SMART_SPLITS_HERDR_RESIZE_AMOUNT:-0.03}"
  "$herdr_bin" pane resize --pane "$pane_id" --direction "$direction" --amount "$amount" >/dev/null
else
  "$herdr_bin" pane focus --pane "$pane_id" --direction "$direction" >/dev/null
fi
