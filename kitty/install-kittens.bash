#!/usr/bin/env bash

PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_CONFIG_PATH="$PREFIX/kitty"
cp -f ./kitty/pass_keys.py "$KITTY_CONFIG_PATH/"
cp -f ./kitty/neighboring_window.py "$KITTY_CONFIG_PATH/"
