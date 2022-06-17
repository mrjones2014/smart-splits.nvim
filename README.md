# smart-splits.nvim

Smart, directional Neovim split resizing and navigation.
`smart-splits.nvim` lets you think about split resizing in terms of
"move the divider to the left/right/up/down" which can feel much more
natural. It also allows you to move through splits in a circular fashion
(e.g. moving left at the left edge jumps to the right edge, and vice versa,
and same for top and bottom edges).

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
    -- set to true to silence the notifications
    -- when entering/exiting persistent resize mode
    silent = false,
    -- must be functions, they will be executed when
    -- entering or exiting the resize mode
    hooks = {
      on_enter = nil,
      on_leave = nil
    }
  }
})
```
> Note: The old way of configuring resize_mode_quit_key and
resize_mode_silent are still supported, but will be discontinued soon.

### Hooks
The hook table allows you to define callbacks for the on_enter and on_leave events of the resize mode.

##### Examples:

Integration with [bufresize.nvim](https://github.com/kwkarlwang/bufresize.nvim).
```lua
require('smart-splits').setup({
  resize_mode = {
    hooks = {
      on_leave = require('bufresize').register
    }
  }
})
```

Custom messages when using resize mode.
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

With Vimscript:

```VimL
" resizing splits
" amount defaults to 3 if not specified
" use absolute values, no + or -
:SmartResizeUp [amount]
:SmartResizeDown [amount]
:SmartResizeLeft [amount]
:SmartResizeRight [amount]
" moving between splits
:SmartCursorMoveUp
:SmartCursorMoveDown
:SmartCursorMoveLeft [same_row]
:SmartCursorMoveRight [same_row]
" persistent resize mode
:SmartResizeMode

" recommended mappings
" resizing splits
nmap <A-h> :lua require('smart-splits').resize_left()<CR>
nmap <A-j> :lua require('smart-splits').resize_down()<CR>
nmap <A-k> :lua require('smart-splits').resize_up()<CR>
nmap <A-l> :lua require('smart-splits').resize_right()<CR>
" moving between splits
nmap <C-h> :lua require('smart-splits').move_cursor_left()<CR>
nmap <C-j> :lua require('smart-splits').move_cursor_down()<CR>
nmap <C-k> :lua require('smart-splits').move_cursor_up()<CR>
nmap <C-l> :lua require('smart-splits').move_cursor_right()<CR>
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
