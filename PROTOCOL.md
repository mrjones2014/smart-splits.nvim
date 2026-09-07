# Backend Protocol

`smart-splits.nvim` ships no multiplexer backends. Support for tmux, Zellij, WezTerm, Kitty and
anything else lives in separate plugins that implement the protocol described here.

Core handles everything inside Neovim: window geometry, wrapping, splitting, buffer swapping. A
backend only answers one question, in three variations: **did you handle this?**

## Versioning

The current protocol version is **3.0.0**. A backend declares the version or range it implements:

```lua
protocol_version = '3.0.0'
-- or a range:
protocol_version = '^3.0.0'
protocol_version = '>=3.0.0 <4.0.0'
```

Core accepts any version or range that overlaps with its supported range. Read the current values from Lua:

```lua
local proto_version = require('smart-splits').PROTOCOL_VERSION --> vim.Version (3.0.0)
local supported_versions = require('smart-splits').SUPPORTED_VERSIONS --> vim.VersionRange (^3.0.0)
```

Protocol versions follow semantic versioning. Additions that do not break existing backends do not bump the major version. When a breaking change does land, core keeps accepting the previous major version for at least one release, so the supported range may span multiple major versions.

A backend whose version or range does not overlap the supported range is reported as an error, disabled, and skipped in favour of the next configured backend. Navigation keeps working with plain Neovim behaviour. Nothing throws.

## Interface

```lua
---@class SmartSplitsBackend
---@field name string
---@field protocol_version string
---@field detect fun():boolean
---@field move fun(direction: SmartSplitsDirection, opts?: SmartSplitsBackendMoveOpts):boolean
---@field resize? fun(direction: SmartSplitsDirection, opts?: SmartSplitsBackendResizeOpts):boolean
---@field activate? fun()
---@field health? fun()
```

`SmartSplitsDirection` is one of `'left'`, `'right'`, `'up'`, `'down'`.

`name`, `protocol_version`, `detect` and `move` are required. A backend missing any of them, or with
one of the wrong type, is reported and disabled.

### Options

Every operation takes `(direction, opts)`. `opts` holds the options core resolved for that call, from
the user's config and whatever they passed at the call site:

```lua
---@class SmartSplitsBackendMoveOpts
---@field at_edge 'stop'|'wrap'|'split'|nil what to do when there is no pane in the given direction

---@class SmartSplitsBackendResizeOpts
---@field amount number|nil cells to resize by, already multiplied by `v:count1`
```

Three rules, so the calls stay pleasant to make by hand and cheap to extend:

- **Core always passes a table**, never `nil`. It may be empty.
- **Every field is optional.** Fall back to your own default for anything absent, rather than
  assuming a value. `opts = opts or {}` at the top of each function covers direct callers.
- **Ignore fields you do not recognise.** Later protocol versions add fields without bumping the
  version, since an unrecognised field can only mean "core knew something you do not use".

So all of these are valid:

```lua
mux.move('left', { at_edge = 'wrap' })
mux.move('left', {}) -- no preference, use your defaults
mux.move('left') -- same, by hand
mux.resize('left', { amount = 5 })
```

Options that only mean something inside Neovim are not forwarded. `move.same_row` is the notable one:
it keeps the cursor on the same screen row across a window boundary, which has no counterpart in a
multiplexer pane.

There is no capabilities table. If your multiplexer cannot resize, **leave the
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

**`opts.at_edge`.** This tells you what the user asked to happen when there is no pane in the given
direction. It is one of `'stop'`, `'wrap'`, `'split'`, or `nil` (when the user's `at_edge` is a
function, which core handles itself). Use it to decide how to behave at the edge:

- `'stop'`: do not move past the edge. Return `false` if there is no pane that way.
- `'wrap'`: if your multiplexer can wrap around its own edges, do so and return `true`. Otherwise
  return `false` and core will wrap among its own windows.
- `'split'`: if your multiplexer can create a new pane, do so and return `true`. Otherwise return
  `false` and core will create a Neovim split.

This matters because many multiplexers wrap around their own edges by default. `tmux select-pane -R`
at the rightmost pane moves to the leftmost one, and core cannot tell that apart from an ordinary
move, so a user who asked to stop at the edge would silently wrap anyway. Honour `opts.at_edge`:

```lua
function M.move(direction, opts)
  opts = opts or {}
  if focus_pane(direction) then
    return true
  end
  -- nothing that way
  if opts.at_edge == 'wrap' then
    return focus_far_pane(opposite[direction])
  elseif opts.at_edge == 'split' then
    return create_pane(direction)
  end
  return false
end
```

If your multiplexer wraps for free and gives you no way to stop it, say so in your README and in
`health()`. Returning `false` when `opts.at_edge` is `'stop'` and you already wrapped is worse than
useless, because core will then also apply `at_edge` on top of the move you just made.

Conversely, when you _can_ wrap or split and the corresponding `opts.at_edge` value is set, prefer
doing it yourself and returning `true`. Otherwise core falls back to its own windows, which is a
smaller wrap or split than the user pictured.

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

### `resize(direction, opts)`

Resize the current pane by `opts.amount` cells. Core calls this only when the current Neovim window
already fills that axis, so nothing inside Neovim can absorb the change.

`opts.amount` is in Neovim's terms, `v:count1 * config.resize.amount`, or `v:count1` times whatever
the caller passed for this resize. Translate it if your multiplexer counts differently. When it is
absent, resize by however much your multiplexer normally would.

The return value is logged but does not change what core does next. Core never falls back to a
Neovim resize here: Neovim shrinks a window that fills the axis into `cmdheight` with no way to
recover the space ([#336](https://github.com/mrjones2014/smart-splits.nvim/issues/336)).

Omit this function if your multiplexer cannot resize panes.

### `activate()`

Called once, when your backend is the one selected, from inside core's own `setup()`. This is where
you register autocommands, warm caches, or set a user variable the multiplexer reads. Note that core
may be lazy loaded, so do not assume `VimEnter` has yet to fire:

```lua
function M.activate()
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

A backend that loses the priority race never gets `activate()` called, so anything you do here is
safe to assume applies to the multiplexer the user is actually inside. This is the only lifecycle
hook in the protocol, and the only place initialization work belongs. Whatever code path your plugin
uses to take configuration is not that place, however it is spelled: see
[Configuration](#configuration).

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
when a call exceeds core's `config.diagnostic.slow_threshold` (100ms by default) and names your
backend in the message. If you shell out, pass a reasonable timeout:

```lua
local result = vim.system({ 'zellij', 'action', 'move-focus', direction }, { timeout = 200 }):wait()
return result.code == 0
```

**Do not expect `detect()` to be re-run.** Core resolves once at startup and caches the result. If
the multiplexer disappears mid-session, return `false` from the operations.

## Configuration

Core passes nothing to your backend, and the protocol has nothing to say about how you take options.
Configuration belongs entirely to your plugin. A `setup(opts)` function, a `vim.g.my_backend` table,
a `config` module the user edits fields on, plain defaults with no configuration at all: all of them
are fine, and core neither calls nor looks for any of them. `setup()` is a convention, not a
requirement, and not one everybody shares.

There is exactly one rule, and it is about **where initialization work goes, not how options
arrive**:

> [!WARNING]
> Your configuration path should be inert and idempotent. Store values and return. Autocommands, subprocesses,
> keymaps, user commands, writes to the multiplexer, anything with a side effect or a cost: those go
> in `activate()`.

The reason is that being configured says nothing about being used. Users might install several backends and
list them in priority order, so every installed backend gets configured on every startup, including
the ones whose multiplexer is not even running:

```lua
return {
  'smart-splits-nvim/smart-splits.nvim',
  dependencies = {
    {
      'smart-splits-nvim/smart-splits-backend-zellij',
      opts = { disable_nav_when_zoomed = true },
    },
    {
      'smart-splits-nvim/smart-splits-backend-kitty',
      opts = { kitty_password = 'my-password' },
    },
  },
  opts = {
    mux = { backend = { 'smart-splits-backend-zellij', 'smart-splits-backend-kitty' } },
  },
}
```

Here lazy.nvim calls `setup(opts)` on both backends, whichever multiplexer the user is actually in,
because that is what lazy.nvim does with an `opts` table. A backend that registered autocommands or
shelled out to its multiplexer from `setup()` would do so from inside Kitty as well as from inside
Zellij. Only one of them gets `activate()`, so only one of them should be doing anything.

Whatever you settle on, calling a configuration function should not be required for use (e.g. your
backend should ship with sensible defaults and not require configuration to work). Users can pass your module inline, in which
case nothing of yours is called before core resolves your backend, so read options from a table with real
defaults rather than assuming they were ever set:

```lua
local M = {
  name = 'my-mux',
  protocol_version = '3.0.0',
}

-- real defaults, usable whether or not the user configured anything
M.config = {
  disable_nav_when_zoomed = false,
}

-- one convention among several; core never calls this
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end
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
  protocol_version = '3.0.0',
}

function M.detect()
  return true
end

function M.move(direction, opts)
  require('smart-splits.log').debug('echo backend: move(%s, %s)', direction, vim.inspect(opts))
  return false
end

function M.resize(direction, opts)
  require('smart-splits.log').debug('echo backend: resize(%s, %s)', direction, vim.inspect(opts))
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

## Testing

This repository is the source of truth for protocol correctness. It ships a Lua module,
`smart-splits.protocol_tests`, that your backend can require in its own test suite to verify
conformance. The module is framework-agnostic: it returns a list of test cases you can run in
busted, plenary, or any other test runner.

Each test is a `{name, fn}` pair. `fn()` returns `true` on pass, or an error string on failure:

```lua
local protocol_tests = require('smart-splits.protocol_tests')

describe('backend conformance', function()
  for _, test in ipairs(protocol_tests.tests(my_backend)) do
    it(test.name, function()
      local result = test.fn()
      if result ~= true then
        error(result)
      end
    end)
  end
end)
```

Or run them all at once without a framework:

```lua
local results = require('smart-splits.protocol_tests').run(my_backend)
for _, r in ipairs(results) do
  print(r.ok and 'PASS' or 'FAIL', r.name, r.ok == true and '' or r.ok)
end
```

The tests cover:

- **Structural validation** — required fields exist with correct types, protocol version overlaps
  the supported range.
- **`detect()`** — returns a boolean, does not throw.
- **`move(direction, {})`** — returns a boolean for each of `left`, `right`, `up`, `down`; does not
  throw.
- **`resize(direction, {amount=1})`** — same, but only when `resize` is present on the backend.
- **`activate()`** — does not throw, if present.
- **`health()`** — does not throw, if present.

Optional fields (`resize`, `activate`, `health`) are only tested when the backend provides them. A
backend that omits `resize` entirely will not see resize tests.

## What core does not give you

- **Pane identifiers.** Core no longer asks for them, and no longer compares them to work out whether
  a move succeeded. Your boolean return is the answer.
- **Layout details.** If you need to know where panes sit, track it yourself.
- **Auto-detection.** Users name their backend explicitly. Core does not guess from environment
  variables.
- **Edge queries.** There is no `current_pane_at_edge`. Core cannot see your layout and does not try.
