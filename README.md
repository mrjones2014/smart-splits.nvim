# smart-resize.nvim

"Smart" resize Neovim splits directionally.

![demo](./demo.gif)

## Install

With Packer.nvim:

```lua
use('mrjones2014/smart-resize.nvim')
```

## Usage

Bind the following functions to keymaps of your choice:

```lua
require('smart-resize').resize_up()
require('smart-resize').resize_down()
require('smart-resize').resize_left()
require('smart-resize').resize_right()
```
