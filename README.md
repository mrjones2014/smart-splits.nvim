# smart-resize.nvim

Smart, directional Neovim split resizing and navigation. Think about split resizing in terms of up, down, left, and right edge movements.
Move cyclicly through splits (moving left at the left edge jumps to the right edge). Extremely lightweight, weighing in at less than 150 lines of code.

![demo](./demo.gif)

## Install

With Packer.nvim:

```lua
use('mrjones2014/smart-resize.nvim')
```

## Usage

With Lua:

```lua
-- resizing
-- amount defaults to 3 if not specified
-- use absolute values, no + or -
require('smart-resize').resize_up(amount)
require('smart-resize').resize_down(amount)
require('smart-resize').resize_left(amount)
require('smart-resize').resize_right(amount)
-- movement
require('smart-resize').move_cursor_up(amount)
require('smart-resize').move_cursor_down(amount)
require('smart-resize').move_cursor_left(amount)
require('smart-resize').move_cursor_right(amount)

-- recommended mappings
-- resizing
vim.keymap.set('n', '<A-h>', require('smart-resize').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-resize').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-resize').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-resize').resize_right)
-- movements
vim.keymap.set('n', '<C-h>', require('smart-resize').move_cursor_left)
vim.keymap.set('n', '<C-j>', require('smart-resize').move_cursor_down)
vim.keymap.set('n', '<C-k>', require('smart-resize').move_cursor_up)
vim.keymap.set('n', '<C-l>', require('smart-resize').move_cursor_right)
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
nmap <A-h> :lua require('smart-resize').move_cursor_left()<CR>
nmap <A-j> :lua require('smart-resize').move_cursor_down()<CR>
nmap <A-k> :lua require('smart-resize').move_cursor_up()<CR>
nmap <A-l> :lua require('smart-resize').move_cursor_right()<CR>
```
