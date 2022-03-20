# smart-resize.nvim

Smart, directional Neovim split resizing. Think about split resizing in terms of up, down, left, and right edge movements.
Extremely lightweight, weighing in at less than 100 lines of code.

![demo](./demo.gif)

## Install

With Packer.nvim:

```lua
use('mrjones2014/smart-resize.nvim')
```

## Usage

With Lua:

```lua
-- amount defaults to 3 if not specified
-- use absolute values, no + or -
require('smart-resize').resize_up(amount)
require('smart-resize').resize_down(amount)
require('smart-resize').resize_left(amount)
require('smart-resize').resize_right(amount)

-- recommended mappings
vim.keymap.set('n', '<A-h>', require('smart-resize').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-resize').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-resize').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-resize').resize_right)
```

With Vimscript:

```VimL
" amount defaults to 3 if not specified
" use absolute values, no + or -
:SmartResizeUp [amount]
:SmartResizeDown [amount]
:SmartResizeLeft [amount]
:SmartResizeRight [amount]

" recommended mappings
nmap <A-h> :lua require('smart-resize').resize_left()<CR>
nmap <A-j> :lua require('smart-resize').resize_down()<CR>
nmap <A-k> :lua require('smart-resize').resize_up()<CR>
nmap <A-l> :lua require('smart-resize').resize_right()<CR>
```
