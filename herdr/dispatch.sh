#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
direction="${2:-}"

case "$mode:$direction" in
move:left | move:down | move:up | move:right | resize:left | resize:down | resize:up | resize:right) ;;
*)
  echo "usage: dispatch.sh move|resize left|down|up|right" >&2
  exit 2
  ;;
esac

herdr_bin="${HERDR_BIN_PATH:-herdr}"
pane_id="${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}"

if [ -z "$pane_id" ]; then
  context_json="${HERDR_PLUGIN_CONTEXT_JSON:-}"
  if command -v python3 >/dev/null 2>&1 && [ -n "$context_json" ]; then
    pane_id="$(
      HERDR_PLUGIN_CONTEXT_JSON="$context_json" python3 - <<'PY'
import json
import os

try:
    print(json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))\
        .get("focused_pane_id", ""))
except Exception:
    pass
PY
    )"
  fi
fi

if [ -z "$pane_id" ]; then
  echo "smart-splits herdr plugin: focused pane id is unavailable" >&2
  exit 1
fi

marker_dir() {
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/smart-splits.nvim/herdr-panes"
}

marker_path() {
  local pane="$1"
  printf '%s/%s\n' "$(marker_dir)" "$pane"
}

is_nvim_pane() {
  local pane="$1"

  # Match tmux's hot-path design: use the state recorded by Neovim on init,
  # and avoid per-keypress CLI/process inspection.
  [ -f "$(marker_path "$pane")" ]
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

nvim_command_for() {
  case "$mode:$direction" in
  resize:left) echo "SmartResizeLeft" ;;
  resize:down) echo "SmartResizeDown" ;;
  resize:up) echo "SmartResizeUp" ;;
  resize:right) echo "SmartResizeRight" ;;
  move:left) echo "SmartCursorMoveLeft" ;;
  move:down) echo "SmartCursorMoveDown" ;;
  move:up) echo "SmartCursorMoveUp" ;;
  move:right) echo "SmartCursorMoveRight" ;;
  esac
}

invoke_nvim_command() {
  local pane="$1"
  local command="$2"
  local server
  local nvim_bin

  server="$(marker_value "$pane" server || true)"
  nvim_bin="$(marker_value "$pane" nvim || true)"

  if [ -z "$server" ]; then
    echo "smart-splits herdr plugin: Neovim pane marker has no RPC server; restart Neovim to refresh the marker" >&2
    return 1
  fi

  if [ -z "$nvim_bin" ]; then
    nvim_bin="${NVIM_BIN:-nvim}"
  fi

  "$nvim_bin" --server "$server" --remote-expr "execute('$command')" >/dev/null
}

if is_nvim_pane "$pane_id"; then
  invoke_nvim_command "$pane_id" "$(nvim_command_for)"
  exit 0
fi

# Load user config from the per-plugin config directory Herdr creates.
# Users set SMART_SPLITS_HERDR_RESIZE_AMOUNT there instead of exporting it on
# the command line. See herdr/config.example for a template.
config_file="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/smart-splits.nvim}/config.sh"
if [ -f "$config_file" ]; then
  # shellcheck source=/dev/null
  . "$config_file"
fi

if [ "$mode" = "resize" ]; then
  amount="${SMART_SPLITS_HERDR_RESIZE_AMOUNT:-0.03}"
  "$herdr_bin" pane resize --pane "$pane_id" --direction "$direction" --amount "$amount" >/dev/null
else
  "$herdr_bin" pane focus --pane "$pane_id" --direction "$direction" >/dev/null
fi
