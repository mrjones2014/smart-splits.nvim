#!/usr/bin/env bash

PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_CONFIG_PATH="$PREFIX/kitty"
cp -f ./pass_keys.py "$KITTY_CONFIG_PATH/"
cp -f ./neighboring_window.py "$KITTY_CONFIG_PATH/"
