# smart-splits.nvim

Smart, directional Neovim split resizing and navigation.
`smart-splits.nvim` lets you think about split resizing in terms of
"move the divider to the left/right/up/down" which can feel much more
natural. It also allows you to move through splits in a circular fashion
(e.g. moving left at the left edge jumps to the right edge, and vice versa,
and same for top and bottom edges).

![demo](./demo.gif)

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
which tries to maintain its own width unless manually resized.

Defaults are shown below:

```lua
require('smart-splits').ignored_buftypes = { 'NvimTree' }
require('smart-splits').ignored_filetypes = {
  'nofile',
  'quickfix',
  'prompt',
}
```

## Usage

With Lua:

```lua
-- resizing
-- amount defaults to 3 if not specified
-- use absolute values, no + or -
require('smart-splits').resize_up(amount)
require('smart-splits').resize_down(amount)
require('smart-splits').resize_left(amount)
require('smart-splits').resize_right(amount)
-- movement
require('smart-splits').move_cursor_up()
require('smart-splits').move_cursor_down()
require('smart-splits').move_cursor_left()
require('smart-splits').move_cursor_right()

-- recommended mappings
-- resizing
vim.keymap.set('n', '<A-h>', require('smart-splits').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-splits').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-splits').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-splits').resize_right)
-- movements
vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
```

With Vimscript:

```VimL
" resizing
" amount defaults to 3 if not specified
" use absolute values, no + or -
:SmartResizeUp [amount]
:SmartResizeDown [amount]
:SmartResizeLeft [amount]
:SmartResizeRight [amount]
" movement
:SmartCursorMoveUp
:SmartCursorMoveDown
:SmartCursorMoveLeft
:SmartCursorMoveRight


" recommended mappings
nmap <A-h> :lua require('smart-splits').move_cursor_left()<CR>
nmap <A-j> :lua require('smart-splits').move_cursor_down()<CR>
nmap <A-k> :lua require('smart-splits').move_cursor_up()<CR>
nmap <A-l> :lua require('smart-splits').move_cursor_right()<CR>
```
