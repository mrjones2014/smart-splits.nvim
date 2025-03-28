#!/usr/bin/env bash

# -------------------------------------------- #
# Config file for `smart-splits.nvim` for TPM. #
# -------------------------------------------- #

get_option() {
    local value=$(tmux show-options -gvq "$1")
    echo "${value:-$2}"
}

no_wrap=$(get_option '@smart-splits_no_wrap' '')

move_left_key=$(get_option  '@smart-splits_move_left_key'  'C-h')
move_down_key=$(get_option  '@smart-splits_move_down_key'  'C-j')
move_up_key=$(get_option    '@smart-splits_move_up_key'    'C-k')
move_right_key=$(get_option '@smart-splits_move_right_key' 'C-l')

resize_left_key=$(get_option  '@smart-splits_resize_left_key'  'M-h')
resize_down_key=$(get_option  '@smart-splits_resize_down_key'  'M-j')
resize_up_key=$(get_option    '@smart-splits_resize_up_key'    'M-k')
resize_right_key=$(get_option '@smart-splits_resize_right_key' 'M-l')

resize_step_size=$(get_option '@smart-splits_resize_step_size' '3')

# Setup all the navigation key-mappings.
setup_navigation() {
    if [ -z $no_wrap ]; then
        tmux bind-key -n "$move_left_key"  if -F '#{@pane-is-vim}' "send-keys $move_left_key"  'select-pane -L'
        tmux bind-key -n "$move_down_key"  if -F '#{@pane-is-vim}' "send-keys $move_down_key"  'select-pane -D'
        tmux bind-key -n "$move_up_key"    if -F '#{@pane-is-vim}' "send-keys $move_up_key"    'select-pane -U'
        tmux bind-key -n "$move_right_key" if -F '#{@pane-is-vim}' "send-keys $move_right_key" 'select-pane -R'
        tmux bind-key -T copy-mode-vi "$move_left_key"  select-pane -L
        tmux bind-key -T copy-mode-vi "$move_down_key"  select-pane -D
        tmux bind-key -T copy-mode-vi "$move_up_key"    select-pane -U
        tmux bind-key -T copy-mode-vi "$move_right_key" select-pane -R
    else
        tmux bind-key -n "$move_left_key"  if -F '#{@pane-is-vim}' "send-keys $move_left_key"  "if -F '#{pane_at_left}'   '' 'select-pane -L'"
        tmux bind-key -n "$move_down_key"  if -F '#{@pane-is-vim}' "send-keys $move_down_key"  "if -F '#{pane_at_bottom}' '' 'select-pane -D'"
        tmux bind-key -n "$move_up_key"    if -F '#{@pane-is-vim}' "send-keys $move_up_key"    "if -F '#{pane_at_top}'    '' 'select-pane -U'"
        tmux bind-key -n "$move_right_key" if -F '#{@pane-is-vim}' "send-keys $move_right_key" "if -F '#{pane_at_right}'  '' 'select-pane -R'"
        tmux bind-key -T copy-mode-vi "$move_left_key"  if -F '#{pane_at_left}'   '' 'select-pane -L'
        tmux bind-key -T copy-mode-vi "$move_down_key"  if -F '#{pane_at_bottom}' '' 'select-pane -D'
        tmux bind-key -T copy-mode-vi "$move_up_key"    if -F '#{pane_at_top}'    '' 'select-pane -U'
        tmux bind-key -T copy-mode-vi "$move_right_key" if -F '#{pane_at_right}'  '' 'select-pane -R'
    fi
}

# Setup all the key-mappings for resizing.
setup_resize() {
    tmux bind-key -n "$resize_left_key"  if -F '#{@pane-is-vim}' "send-keys $resize_left_key"  "resize-pane -L $resize_step_size"
    tmux bind-key -n "$resize_down_key"  if -F '#{@pane-is-vim}' "send-keys $resize_down_key"  "resize-pane -D $resize_step_size"
    tmux bind-key -n "$resize_up_key"    if -F '#{@pane-is-vim}' "send-keys $resize_up_key"    "resize-pane -U $resize_step_size"
    tmux bind-key -n "$resize_right_key" if -F '#{@pane-is-vim}' "send-keys $resize_right_key" "resize-pane -R $resize_step_size"
}

main() {
    setup_navigation
    setup_resize
}

main
