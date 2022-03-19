# smart-resize.nvim

Resize Neovim splits based on the "direction" you want to resize in.

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
