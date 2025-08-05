#!/usr/bin/env bash

PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_CONFIG_PATH="$PREFIX/kitty"
cp -f ./kitty/relative_resize.py "$KITTY_CONFIG_PATH/"
cp -f ./kitty/split_window.py "$KITTY_CONFIG_PATH/"
