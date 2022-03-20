# smart-resize.nvim

"Smart" resize Neovim splits directionally. Extremely lightweight (less than 100 lines of code).

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
```

With Vimscript:

```VimL
" amount defaults to 3 if not specified
" use absolute values, no + or -
:SmartResizeUp [amount]
:SmartResizeDown [amount]
:SmartResizeLeft [amount]
:SmartResizeRight [amount]
```
