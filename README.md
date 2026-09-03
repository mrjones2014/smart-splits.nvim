<div align="center">

# 🧠 `smart-splits.nvim`

</div>

> [!NOTE]
> This repo recently moved to a new `smart-splits-nvim` GitHub org!
> See [#488](https://github.com/mrjones2014/smart-splits.nvim/issues/488) / [#492](https://github.com/mrjones2014/smart-splits.nvim/issues/492)
> for details.

🧠 Smarter and more intuitive split pane management that uses a mental model of left/right/up/down
instead of wider/narrower/taller/shorter for resizing. Navigate seamlessly between Neovim windows and
terminal multiplexer panes.

<video src="https://github.com/user-attachments/assets/e516399d-0c49-4c3d-b748-3ee0e4262898"></video>

**Table of Contents**

<!--toc:start-->

- [🧠 `smart-splits.nvim`](#🧠-smart-splitsnvim)
  - [Install](#install)
  - [Usage](#usage)
    - [Key Mappings](#key-mappings)
    - [Lua API](#lua-api)
    - [Commands](#commands)
  - [Configuration](#configuration)
    - [Ignore Lists](#ignore-lists)
    - [At Edge Behavior](#at-edge-behavior)
  - [Multiplexer Backends](#multiplexer-backends)
    - [Available Backends](#available-backends)
    - [Multiple Backends](#multiple-backends)
    - [Writing a Backend](#writing-a-backend)
  - [Troubleshooting](#troubleshooting)
  - [Migrating from v2](#migrating-from-v2)
  <!--toc:end-->

## Install

Requires Neovim 0.11 or newer. Versions are tagged, see
[Releases](https://github.com/mrjones2014/smart-splits.nvim/releases).

With lazy.nvim:

```lua
{
  'mrjones2014/smart-splits.nvim',
  -- pin a major version to opt out of protocol changes
  version = '^3.0.0',
}
```

Calling `setup()` is optional. Without it you get the defaults and no multiplexer integration.

## Usage

### Key Mappings

`smart-splits.nvim` sets no mappings for you. The recommended set:

```lua
-- resizing splits, these accept a count, so `10<A-h>` resizes by 10 * config.resize.amount
vim.keymap.set('n', '<A-h>', require('smart-splits').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-splits').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-splits').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-splits').resize_right)
-- moving between splits
vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
-- swapping buffers between windows
vim.keymap.set('n', '<leader><leader>h', require('smart-splits').swap_buf_left)
vim.keymap.set('n', '<leader><leader>j', require('smart-splits').swap_buf_down)
vim.keymap.set('n', '<leader><leader>k', require('smart-splits').swap_buf_up)
vim.keymap.set('n', '<leader><leader>l', require('smart-splits').swap_buf_right)
```

### Lua API

```lua
local ss = require('smart-splits')

-- resize, `opts` is `{ amount = n }` or a bare number, defaulting to
-- `config.resize.amount`; either way `v:count1` multiplies it
ss.resize_left(opts)
ss.resize_right(opts)
ss.resize_up(opts)
ss.resize_down(opts)

-- move the cursor, `opts` may override `same_row` and `at_edge` for this call
ss.move_cursor_left(opts)
ss.move_cursor_right(opts)
ss.move_cursor_up(opts)
ss.move_cursor_down(opts)

-- swap the current buffer with a neighbor, `opts` may override `move_cursor`
ss.swap_buf_left(opts)
ss.swap_buf_right(opts)
ss.swap_buf_up(opts)
ss.swap_buf_down(opts)
```

### Commands

| Command                        | Description                           |
| ------------------------------ | ------------------------------------- |
| `:SmartResizeLeft [amount]`    | Resize left                           |
| `:SmartResizeRight [amount]`   | Resize right                          |
| `:SmartResizeUp [amount]`      | Resize up                             |
| `:SmartResizeDown [amount]`    | Resize down                           |
| `:SmartCursorMoveLeft`         | Move the cursor left                  |
| `:SmartCursorMoveRight`        | Move the cursor right                 |
| `:SmartCursorMoveUp`           | Move the cursor up                    |
| `:SmartCursorMoveDown`         | Move the cursor down                  |
| `:SmartSwapLeft`               | Swap the buffer left                  |
| `:SmartSwapRight`              | Swap the buffer right                 |
| `:SmartSwapUp`                 | Swap the buffer up                    |
| `:SmartSwapDown`               | Swap the buffer down                  |
| `:SmartSplitsLog`              | Open the log file                     |
| `:SmartSplitsLogLevel {level}` | Change the log level for this session |

## Configuration

Defaults:

```lua
require('smart-splits').setup({
  -- buffers to leave alone, see Ignore Lists below
  ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
  ignored_filetypes = { 'NvimTree' },

  resize = {
    -- cells to resize by, multiplied by `v:count1`
    amount = 3,
    -- added to `eventignore` for the duration of a resize
    ignored_events = { 'BufEnter', 'WinEnter' },
  },

  move = {
    -- 'stop' | 'wrap' | 'split' | fun(ctx), see At Edge Behavior below
    at_edge = 'wrap',
    -- keep the cursor on the same screen row when moving horizontally
    same_row = false,
  },

  swap = {
    -- follow the buffer into its new window
    move_cursor = false,
  },

  mux = {
    -- a backend, a list of backends in priority order, or a function returning
    -- either; see Multiplexer Backends below
    backend = nil,
    -- warn when backends are configured but none of them detected
    warn_if_unusable = true,
  },

  log = {
    -- 'trace' | 'debug' | 'info' | 'warn' | 'error'
    level = 'info',
    -- `true` for the default path, a string for a custom one, `false` to disable
    file = true,
  },
})
```

### Ignore Lists

`ignored_buftypes` and `ignored_filetypes` mark windows that `smart-splits.nvim` should leave alone:
they are skipped when working out resize geometry, and `at_edge = 'split'` will not split them.

Both can be overridden per feature. A bare list replaces the top level one:

```lua
{
  ignored_filetypes = { 'NvimTree' },
  -- resizing ignores only Trouble, moving still ignores only NvimTree
  resize = { ignored_filetypes = { 'Trouble' } },
}
```

Set `inherit = true` to add to the top level list instead of replacing it:

```lua
{
  ignored_filetypes = { 'NvimTree', 'neo-tree' },
  -- resizing ignores NvimTree, neo-tree and Trouble
  resize = { ignored_filetypes = { inherit = true, 'Trouble' } },
}
```

### At Edge Behavior

`move.at_edge` decides what happens when there is no Neovim window in the direction you moved, and
the multiplexer backend did not handle it either.

| Value      | Behavior                                                                 |
| ---------- | ------------------------------------------------------------------------ |
| `'wrap'`   | Jump to the Neovim window on the opposite edge                           |
| `'stop'`   | Stay where you are                                                       |
| `'split'`  | Create a split, asking the backend first, falling back to a Neovim split |
| `fun(ctx)` | Decide for yourself                                                      |

`at_edge` only ever runs when the backend declined the move, so how far `'wrap'` reaches depends on
the multiplexer. Take a Neovim pane sitting at the right edge of the multiplexer, with another pane to
its left, and press the "move right" key from Neovim's rightmost window:

- A multiplexer that can wrap around its own edges moves focus to that left pane and reports the move
  as handled, so you wrap across the whole screen and `at_edge` never runs.
- One that cannot reports the move as unhandled, and `'wrap'` then wraps among Neovim's own windows.

Core tells the backend which behavior you asked for, so `'stop'` also stops at the multiplexer's
edges rather than letting a multiplexer that wraps by default wrap anyway. Backends are expected to
honour that, but it is their code doing it, so check yours if `'stop'` does not stop.

The function form receives:

```lua
---@class SmartSplitsAtEdgeContext
---@field backend SmartSplitsBackend|nil the resolved backend, `nil` if none resolved
---@field direction SmartSplitsDirection the direction you moved, so also the edge you are on
---@field split fun() split the current window towards `direction`
---@field wrap fun() jump to the window on the opposite edge
```

For example, wrap horizontally but stop vertically:

```lua
{
  move = {
    at_edge = function(ctx)
      if ctx.direction == 'left' or ctx.direction == 'right' then
        ctx.wrap()
      end
    end,
  },
}
```

## Multiplexer Backends

**Core ships no backends.** Support for tmux, Zellij, WezTerm, Kitty and anything else lives in
separate plugins, so each one can be maintained by people who actually use it.

Install a backend plugin and name it:

```lua
{
  'mrjones2014/smart-splits.nvim',
  dependencies = {
    {
      'smart-splits-nvim/smart-splits-backend-zellij',
      -- backend options belong to the backend plugin
      opts = { disable_nav_when_zoomed = true },
    },
  },
  opts = {
    mux = { backend = 'smart-splits-backend-zellij' },
  },
}
```

There is no auto-detection. Naming your backend explicitly is what replaced it.

### Available Backends

| Multiplexer | Backend                                                                                         |
| ----------- | ----------------------------------------------------------------------------------------------- |
| Zellij      | [smart-splits-backend-zellij](https://github.com/smart-splits-nvim/smart-splits-backend-zellij) |

Using tmux, WezTerm, Kitty or Herdr? Those backends shipped in core through v2 and need maintainers.
Either stay on the `v2` tag, or [volunteer to maintain
one](https://github.com/mrjones2014/smart-splits.nvim/issues/488).

### Multiple Backends

`mux.backend` accepts a list in priority order. The first backend whose `detect()` returns `true`
wins, which covers the case where you are usually in one multiplexer and occasionally in another:

```lua
{
  mux = {
    -- inside tmux, use tmux; otherwise fall back to Kitty
    backend = { 'smart-splits-backend-tmux', 'smart-splits-backend-kitty' },
  },
}
```

It also accepts a module table directly, or a function returning any of the above. The function form
defers the `require` until startup, which helps if your backend plugin is lazy loaded:

```lua
{
  mux = {
    backend = function()
      return { require('smart-splits-backend-tmux'), require('smart-splits-backend-kitty') }
    end,
  },
}
```

Resolution happens once, during `setup()`. A backend that fails to load, implements an unsupported
protocol version, or is missing a required field is reported and skipped, and the next one is tried.

### Writing a Backend

See [`PROTOCOL.md`](./PROTOCOL.md), or `:help smart-splits-protocol`. A backend needs four fields:

```lua
return {
  name = 'my-mux',
  protocol_version = 3,
  detect = function()
    return vim.env.MY_MUX ~= nil
  end,
  move = function(direction, opts)
    return focus_pane(direction, { wrap = opts.wrap })
  end,
}
```

Every operation takes `(direction, opts)`, where `opts` holds the options core resolved for that
call, such as `wrap` for `move` and `amount` for `resize`. Fields are optional, so a backend falls
back to its own defaults for anything the user did not ask for.

There is one optional lifecycle hook, `activate()`. Core calls it once, only on the backend it
resolved, and that is where autocommands, caches and anything else with a side effect belong.

Backend options are the backend's own business and core passes none of them along. Take them however
you like, `setup(opts)` or `vim.g` or a config module; the protocol does not care and core calls none
of them. It only asks that whichever path you pick stays inert, storing values and nothing more,
because every installed backend gets configured on startup including the ones whose multiplexer is
not running. Only the resolved backend gets `activate()`.

You can also pass a table like this inline, without publishing a plugin at all.

## Troubleshooting

Start with `:checkhealth smart-splits`. It reports your resolved config, every backend it tried and
why each one was accepted or skipped, and runs each backend's own health check.

For anything involving movement or resizing, turn the log up and reproduce it:

```vim
:SmartSplitsLogLevel debug
:SmartSplitsLog
```

## Migrating from v2

v2 remains available via its git tag. To move to v3:

**1. Install a backend plugin.** Core ships none. See [Available Backends](#available-backends).

**2. Rename your config keys.** Everything is grouped by feature now. `setup()` reports any v2 keys
it finds, with the new location, and `:checkhealth smart-splits` repeats the report.

| v2                            | v3                      |
| ----------------------------- | ----------------------- |
| `default_amount`              | `resize.amount`         |
| `ignored_events`              | `resize.ignored_events` |
| `at_edge`                     | `move.at_edge`          |
| `move_cursor_same_row`        | `move.same_row`         |
| `cursor_follows_swapped_bufs` | `swap.move_cursor`      |
| `multiplexer_integration`     | `mux.backend`           |
| `log_level`                   | `log.level`             |
| `ignored_buftypes`            | unchanged               |
| `ignored_filetypes`           | unchanged               |

**3. Drop what no longer exists.**

| Removed                                                          | Why                                                        |
| ---------------------------------------------------------------- | ---------------------------------------------------------- |
| `disable_multiplexer_nav_when_zoomed`                            | Zoom is handled inside the backend, configure it there     |
| `float_win_behavior`                                             | Floating windows always act on the previous window         |
| `wezterm_cli_path`, `kitty_password`, `zellij_move_focus_or_tab` | Moved to their backend plugins                             |
| `tmux_integration`, `wrap_at_edge`                               | Deprecated in v2, now gone                                 |
| `vim.g.smart_splits_multiplexer_integration`                     | Unnecessary, backends are required lazily                  |
| `move_cursor_previous`                                           | Removed, it could never work across a multiplexer boundary |
| `require('smart-splits.mux')`                                    | Replaced by `require('smart-splits.backend')`              |
| `ctx.mux` in `at_edge`                                           | Now `ctx.backend`                                          |

**4. Post install hooks are gone.** The Kitty kittens, the tmux plugin file, the WezTerm plugin and
the Herdr manifest all moved out of this repository. Remove any `build`/`run` hook you had.
