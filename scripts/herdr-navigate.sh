#!/usr/bin/env bash
#
# smart-splits.nvim — herdr side
#
# Invoked by a herdr keybind as: herdr-navigate.sh <left|down|up|right>
#
# Decision table per keypress:
#   1. Focused pane's foreground process matches Vim (or SMART_SPLITS_HERDR_PASSTHROUGH_RE):
#      forward the key into the pane and let the editor/app decide.
#   2. Otherwise, try `herdr pane focus --direction DIR`:
#      - there is a neighbor (changed == true): focus moved, done.
#      - no neighbor (reason == "no_neighbor") or the focus command fails: send the
#        key back to the pane so the shell/app keeps its default binding (e.g. C-l
#        = clear screen, C-h = backspace).
#
# Requires `jq`. Without it, Vim detection is skipped: keys move herdr focus when
# a neighbor exists, and fall through to send-keys otherwise.

set -euo pipefail

dir="${1:?usage: herdr-navigate.sh <left|down|up|right>}"
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_PANE_ID:-}"

case "$dir" in
  left)  key="ctrl+h" ;;
  down)  key="ctrl+j" ;;
  up)    key="ctrl+k" ;;
  right) key="ctrl+l" ;;
  *) echo "herdr-navigate.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Foreground process names that mean "Vim is in control of this pane".
# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
vim_re='^g?(view|l?n?vim?x?)(diff)?$'

# Opt-in passthrough for other TUIs that own Ctrl+h/j/k/l themselves,
# e.g. SMART_SPLITS_HERDR_PASSTHROUGH_RE='^(lazygit|k9s|vi-sql)$'
passthrough_re="${SMART_SPLITS_HERDR_PASSTHROUGH_RE:-}"

forward=0
if [ -n "$pane" ] && command -v jq >/dev/null 2>&1; then
  if "$herdr" pane process-info --current 2>/dev/null \
    | jq -e --arg vim "$vim_re" --arg pass "$passthrough_re" \
        '.result.process_info.foreground_processes[]?.name
         | ascii_downcase
         | select(test($vim) or ($pass != "" and (try test($pass) catch false)))' >/dev/null 2>&1; then
    forward=1
  fi
fi

if [ "$forward" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane" "$key"
fi

# Non-Vim pane: move focus if there is a neighbor in that direction,
# otherwise let the key fall through to the app (shell C-l = clear, etc.).
focus_output="$("$herdr" pane focus --direction "$dir" --current 2>/dev/null)" && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && [ -n "$focus_output" ] && command -v jq >/dev/null 2>&1; then
  reason="$(printf '%s' "$focus_output" | jq -r '.result.focus.reason // empty' 2>/dev/null)"
  changed="$(printf '%s' "$focus_output" | jq -r '.result.focus.changed // false' 2>/dev/null)"
  if [ "$changed" = "true" ]; then
    exit 0
  fi
  if [ "$reason" = "no_neighbor" ]; then
    exec "$herdr" pane send-keys "$pane" "$key"
  fi
fi
# Fallback: if we couldn't determine state, let the key through rather than eating it.
exec "$herdr" pane send-keys "$pane" "$key"
