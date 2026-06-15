#!/usr/bin/env bash

PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_CONFIG_PATH="$PREFIX/kitty"
# this gives you the directory path that this script lives inside
SCRIPT_DIR="$(dirname "$(realpath $0)")"
cp -f "$SCRIPT_DIR/neighboring_window.py" "$KITTY_CONFIG_PATH/"
cp -f "$SCRIPT_DIR/relative_resize.py" "$KITTY_CONFIG_PATH/"
cp -f "$SCRIPT_DIR/split_window.py" "$KITTY_CONFIG_PATH/"
