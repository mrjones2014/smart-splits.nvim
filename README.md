# smart-splits.nvim

Smart, directional Neovim split resizing and navigation. Think about split resizing in terms of up, down, left, and right edge movements.
Move cyclicly through splits (moving left at the left edge jumps to the right edge).
Extremely lightweight, weighing in at less than 150 source lines of code.

![demo](./demo.gif)

## Install

With Packer.nvim:

```lua
use('mrjones2014/smart-splits.nvim')
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
