# Backend Protocol

`smart-splits.nvim` ships no multiplexer backends. Support for tmux, Zellij, WezTerm, Kitty and
anything else lives in separate plugins that implement the protocol described here.

Core handles everything inside Neovim: window geometry, wrapping, splitting, buffer swapping. A
backend only answers one question, in three variations: **did you handle this?**

## Versioning

The current protocol version is **3**. A backend declares the major version it implements:

```lua
protocol_version = 3
```

Core accepts any version in its supported set. Read the current values from Lua:

```lua
require('smart-splits').PROTOCOL_VERSION            --> 3
require('smart-splits.backend').SUPPORTED_VERSIONS  --> { 3 }
```

Protocol versions are major versions only. Additions that do not break existing backends do not bump
it. When a breaking change does land, core keeps accepting the previous version for at least one
release, so the supported set may hold more than one entry.

A backend outside the supported set is reported as an error, disabled, and skipped in favour of the
next configured backend. Navigation keeps working with plain Neovim behaviour. Nothing throws.

## Interface

```lua
---@class SmartSplitsBackend
---@field name string
---@field protocol_version number
---@field detect fun():boolean
---@field move fun(direction: SmartSplitsDirection, opts: SmartSplitsMoveOptions):boolean
---@field resize? fun(direction: SmartSplitsDirection, amount: number):boolean
---@field split? fun(direction: SmartSplitsDirection):boolean
---@field setup? fun()
---@field health? fun()
```

`SmartSplitsDirection` is one of `'left'`, `'right'`, `'up'`, `'down'`.

`name`, `protocol_version`, `detect` and `move` are required. A backend missing any of them, or with
one of the wrong type, is reported and disabled.

There is no capabilities table. If your multiplexer cannot resize or cannot split, **leave the
function out entirely**. Core checks whether the function exists.

## Contracts

### `detect()`

Answers "is this multiplexer usable right now?". Core calls it once when resolving backends, and
again during `:checkhealth`.

Must be cheap and free of side effects: environment variables, `vim.fn.executable`, at most a
`vim.uv.fs_stat`. **No subprocesses.** Core resolves backends inside its own `setup()`, and a
`detect()` that shells out delays every startup.

```lua
function M.detect()
  return vim.env.ZELLIJ ~= nil
end
```

### `move(direction, opts)`

Move focus one pane in `direction`. Core calls this only when the cursor is already at the edge of
the Neovim window layout, so there is no window left to move to.

Return `true` when you moved, `false` when you did not. On `false`, core applies the user's
`move.at_edge` setting: stop, wrap around the Neovim windows, split, or call their function.

The return value is checked with `== true`. A backend that forgets to return gets treated as "did not
handle", never as success.

```lua
---@class SmartSplitsMoveOptions
---@field wrap boolean whether the user asked for wrapping
```

`opts` carries what core knows about the user's intent and you cannot work out for yourself. Later
protocol versions may add fields, so ignore any you do not recognise.

**Wrapping.** There is no `wrap` capability field; whether you wrap is a per-call decision, and
`opts.wrap` is how you make it. It is `true` only when the user set `move.at_edge = 'wrap'`.

This matters because many multiplexers wrap around their own edges by default. `tmux select-pane -R`
at the rightmost pane moves to the leftmost one, and core cannot tell that apart from an ordinary
move, so a user who asked to stop at the edge would silently wrap anyway. Honour `opts.wrap`:

```lua
function M.move(direction, opts)
  if focus_pane(direction) then
    return true
  end
  -- nothing that way, so wrapping is the only way to move
  if opts.wrap then
    return focus_far_pane(opposite[direction])
  end
  return false
end
```

If your multiplexer wraps for free and gives you no way to stop it, say so in your README and in
`health()`. Returning `false` when `opts.wrap` is false and you already wrapped is worse than
useless, because core will then also apply `at_edge` on top of the move you just made.

Conversely, when you *can* wrap and `opts.wrap` is true, prefer doing it yourself and returning
`true`. Otherwise core falls back to wrapping among Neovim's own windows, which is a smaller wrap
than the user pictured.

**Zoom.** Entirely yours. Core has no concept of a zoomed pane. If your multiplexer can zoom and the
user wants navigation disabled while zoomed, return `false` from `move()` and expose your own option
for it:

```lua
function M.move(direction, opts)
  if M.config.disable_nav_when_zoomed and is_zoomed() then
    return false
  end
  return focus_pane(direction)
end
```

### `resize(direction, amount)`

Resize the current pane by `amount` cells. Core calls this only when the current Neovim window
already fills that axis, so nothing inside Neovim can absorb the change.

`amount` is in Neovim's terms, `v:count1 * config.resize.amount`. Translate it if your multiplexer
counts differently.

The return value is logged but does not change what core does next. Core never falls back to a
Neovim resize here: Neovim shrinks a window that fills the axis into `cmdheight` with no way to
recover the space ([#336](https://github.com/mrjones2014/smart-splits.nvim/issues/336)).

Omit this function if your multiplexer cannot resize panes.

### `split(direction)`

Create a new pane in `direction`. Core calls this only when `move.at_edge` is `'split'` and the
cursor is at the edge of the layout.

Return `true` when you created a pane. On `false`, core creates a Neovim split instead.

Omit this function if your multiplexer cannot create panes on demand.

### `setup()`

Called once, when your backend is the one selected, from inside core's `setup()`. This is where you
register autocommands, warm caches, or set a user variable the multiplexer reads. Note that core may
be lazy loaded, so do not assume `VimEnter` has yet to fire:

```lua
function M.setup()
  -- do it now as well as on resume: if the user lazy loads smart-splits.nvim,
  -- `VimEnter` has already fired by the time this runs
  set_pane_marker(true)
  vim.api.nvim_create_autocmd('VimResume', {
    callback = function()
      set_pane_marker(true)
    end,
  })
  vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeavePre' }, {
    callback = function()
      set_pane_marker(false)
    end,
  })
end
```

A backend that loses the priority race never gets `setup()` called.

### `health()`

Called during `:checkhealth smart-splits`. **Core emits the section header for you**, so call only
`vim.health.ok`, `vim.health.info`, `vim.health.warn` and `vim.health.error`. Do not call
`vim.health.start` yourself.

Core runs `health()` for every backend that passed validation, not just the one in use, so a backend
that did not activate can still explain why. That means `health()` must tolerate being called when
`detect()` returns `false` and the multiplexer is not present.

## Operational requirements

**Never throw.** Every call core makes is wrapped, and a throwing backend degrades to `at_edge`
behaviour, but the error is reported to the user as your backend's fault. When the multiplexer is
unreachable, return `false`.

**Return promptly.** These functions run on every keypress that reaches a window edge. Core warns
when a call exceeds 100ms and names your backend in the message. If you shell out, pass a timeout:

```lua
local result = vim.system({ 'zellij', 'action', 'move-focus', direction }, { timeout = 200 }):wait()
return result.code == 0
```

**Do not expect `detect()` to be re-run.** Core resolves once at startup and caches the result. If
the multiplexer disappears mid-session, return `false` from the operations.

## Configuration

Core passes nothing to your backend. Options belong to your plugin:

```lua
{
  'smart-splits-nvim/smart-splits.nvim',
  dependencies = {
    {
      'smart-splits-nvim/smart-splits-backend-zellij',
      opts = { disable_nav_when_zoomed = true },
    },
  },
  opts = {
    mux = { backend = 'smart-splits-backend-zellij' },
  },
}
```

Users can also pass your module directly, or a list in priority order, or a function returning
either. All of those reach your backend the same way, so there is nothing extra to support.

## Publishing

Name the repository `smart-splits-backend-<name>` and export the backend from its root module, so
`mux.backend = 'smart-splits-backend-<name>'` works without the user knowing your internal layout.

## Worked example

`tests/fixtures/echo_backend.lua` in this repository is a complete, valid backend. It records every
call and handles nothing, which makes it useful for watching core's delegation points fire:

```lua
---@class EchoBackend: SmartSplitsBackend
local M = {
  name = 'echo',
  protocol_version = 3,
}

function M.detect()
  return true
end

function M.move(direction, opts)
  require('smart-splits.log').debug('echo backend: move(%s, wrap=%s)', direction, opts.wrap)
  return false
end

function M.resize(direction, amount)
  require('smart-splits.log').debug('echo backend: resize(%s, %s)', direction, amount)
  return false
end

function M.split(direction)
  require('smart-splits.log').debug('echo backend: split(%s)', direction)
  return false
end

function M.health()
  vim.health.ok('echo backend is loaded, it records calls and handles nothing')
end

return M
```

Point `mux.backend` at an inline table like this and turn the log level up to see exactly when core
delegates:

```lua
require('smart-splits').setup({
  mux = { backend = require('my-backend') },
  log = { level = 'debug' },
})
```

Then drive your movement keys and read `:SmartSplitsLog`.

## What core does not give you

- **Pane identifiers.** Core no longer asks for them, and no longer compares them to work out whether
  a move succeeded. Your boolean return is the answer.
- **Layout details.** If you need to know where panes sit, track it yourself.
- **Auto-detection.** Users name their backend explicitly. Core does not guess from environment
  variables.
- **Edge queries.** There is no `current_pane_at_edge`. Core cannot see your layout and does not try.
