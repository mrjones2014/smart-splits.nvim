# smart-splits.nvim

Smart, directional Neovim split resizing and navigation, with `tmux` pane navigation.
`smart-splits.nvim` lets you think about split resizing in terms of
"move the divider to the left/right/up/down" which can feel much more
natural. It also allows you to move through splits in a circular fashion
(e.g. moving left at the left edge jumps to the right edge, and vice versa,
and same for top and bottom edges). Additionally, if enabled, it can
provide seamless navigation between Neovim splits and `tmux` panes.
See [Tmux Integration](#tmux-integration)

![demo](https://user-images.githubusercontent.com/8648891/159472445-ef680c42-f0fc-4c21-9ab7-0590a89da95b.gif)

## Install

With Packer.nvim:

```lua
use('mrjones2014/smart-splits.nvim')
```

## Configuration

You can set ignored `buftype`s or `filetype`s which will be ignored when
figuring out if your cursor is currently at an edge split for resizing.
This is useful in order to ignore "sidebar" type buffers while resizing,
such as [nvim-tree.lua](https://github.com/kyazdani42/nvim-tree.lua)
which tries to maintain its own width unless manually resized. Note that
nothing is ignored when moving between splits, only when resizing.

Defaults are shown below:

```lua
require('smart-splits').setup({
  -- Ignored filetypes (only while resizing)
  ignored_filetypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  -- Ignored buffer types (only while resizing)
  ignored_buftypes = { 'NvimTree' },
  -- when moving cursor between splits left or right,
  -- place the cursor on the same row of the *screen*
  -- regardless of line numbers. False by default.
  -- Can be overridden via function parameter, see Usage.
  move_cursor_same_row = false,
  -- resize mode options
  resize_mode = {
    -- key to exit persistent resize mode
    quit_key = '<ESC>',
    -- keys to use for moving in resize mode
    -- in order of left, down, up' right
    resize_keys = { 'h', 'j', 'k', 'l' },
    -- set to true to silence the notifications
    -- when entering/exiting persistent resize mode
    silent = false,
    -- must be functions, they will be executed when
    -- entering or exiting the resize mode
    hooks = {
      on_enter = nil,
      on_leave = nil
    }
  },
  -- ignore these autocmd events (via :h eventignore) while processing
  -- smart-splits.nvim computations, which involve visiting different
  -- buffers and windows. These events will be ignored during processing,
  -- and un-ignored on completed. This only applies to resize events,
  -- not cursor movement events.
  ignored_events = {
    'BufEnter',
    'WinEnter',
  },
  -- set to true to enable tmux integration
  tmux_integration = false,
})
```

### Hooks

The hook table allows you to define callbacks for the `on_enter` and `on_leave` events of the resize mode.

##### Examples:

Integration with [bufresize.nvim](https://github.com/kwkarlwang/bufresize.nvim):

```lua
require('smart-splits').setup({
  resize_mode = {
    hooks = {
      on_leave = require('bufresize').register
    }
  }
})
```

Custom messages when using resize mode:

```lua
require('smart-splits').setup({
  resize_mode = {
    silent = true,
    hooks = {
      on_enter = function() vim.notify('Entering resize mode') end,
      on_leave = function() vim.notify('Exiting resize mode, bye') end
    }
  }
})
```

## Usage

With Lua:

```lua
-- resizing splits
-- amount defaults to 3 if not specified
-- use absolute values, no + or -
require('smart-splits').resize_up(amount)
require('smart-splits').resize_down(amount)
require('smart-splits').resize_left(amount)
require('smart-splits').resize_right(amount)
-- moving between splits
-- pass same_row as a boolean to override the default
-- for the move_cursor_same_row config option.
-- See Configuration.
require('smart-splits').move_cursor_up()
require('smart-splits').move_cursor_down()
require('smart-splits').move_cursor_left(same_row)
require('smart-splits').move_cursor_right(same_row)
-- persistent resize mode
-- temporarily remap 'h', 'j', 'k', and 'l' to
-- smart resize left, down, up, and right, respectively,
-- press <ESC> to stop resize mode (unless you've set a different key in config)
require('smart-splits').start_resize_mode()

-- recommended mappings
-- resizing splits
vim.keymap.set('n', '<A-h>', require('smart-splits').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-splits').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-splits').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-splits').resize_right)
-- moving between splits
vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
```

### Tmux Integration

`smart-splits.nvim` can also enable seamless navigation between Neovim splits and `tmux` panes.
You will need to set up keymaps in your tmux config to match the Neovim keymaps.

You can either add the following snippet to your `~/.tmux.conf`/`~/.config/tmux/tmux.conf` file (customizing the keys if desired):

```tmux
# Smart pane switching with awareness of Vim splits.
# See: https://github.com/christoomey/vim-tmux-navigator
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-l' select-pane -R
bind-key -T copy-mode-vi 'C-\' select-pane -l
```

Or, alternatively, install the [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator#tmux) `tmux` plugin
with [Tmux Plugin Manager (TPM)](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'christoomey/vim-tmux-navigator'
run '~/.tmux/plugins/tpm/tpm'
```

### Getting the Option Key Working on MacOS

Note that to use the alt/option key in keymaps on macOS,
you may need to change some terminal settings for Neovim
to recognize the key properly.

#### Kitty

Add the following configuration option to `~/.config/kitty/kitty.conf`:

```conf
macos_option_as_alt both
```

#### Alacritty

Add the following key bindings to `~/.config/alacritty/alacritty.yml`:

```yaml
# for Alt+h/j/k/l
key_bindings:
  - { key: J, mods: Alt, chars: "\x1bj" }
  - { key: K, mods: Alt, chars: "\x1bk" }
  - { key: H, mods: Alt, chars: "\x1bh" }
  - { key: L, mods: Alt, chars: "\x1bl" }
```

#### iTerm2

Press <kbd>⌘</kbd>+<kbd>,</kbd> to open preferences, go to the "Profiles" top tab,
then go to the "Keys" tab and change "Left Option key" and/or "Right Option key"
to "Esc+".

![iTerm2 settings](https://user-images.githubusercontent.com/8648891/159472029-a521a345-61bd-453c-8230-9a563b9c56c1.png)
