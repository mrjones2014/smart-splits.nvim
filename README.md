<div align="center">

# 🧠 `smart-splits.nvim`

</div>

🧠 Smarter and more intuitive split pane management that uses a mental model of left/right/up/down
instead of wider/narrower/taller/shorter for resizing. Supports seamless navigation between Neovim and terminal
multiplexer split panes. See [Multiplexer Integrations](#multiplexer-integrations).

<video src="https://github.com/user-attachments/assets/e516399d-0c49-4c3d-b748-3ee0e4262898"></video>

**Table of Contents**

<!--toc:start-->

- [Install](#install)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Key Mappings](#key-mappings)
  - [Lua API](#lua-api)
  - [Multiplexer Integrations](#multiplexer-integrations)
    - [Tmux](#tmux)
    - [Zellij](#zellij)
      - [Troubleshooting](#troubleshooting)
    - [Wezterm](#wezterm)
    - [Kitty](#kitty)
      - [Credits](#credits)
  - [Multiplexer Lua API](#multiplexer-lua-api)

<!--toc:end-->

## Install

`smart-splits.nvim` now supports semantic versioning via git tags. See [Releases](https://github.com/mrjones2014/smart-splits.nvim/releases)
for a full list of versions and their changelogs, starting from 1.0.0.

With Packer.nvim:

```lua
use('mrjones2014/smart-splits.nvim')
-- or use a specific version
use({ 'mrjones2014/smart-splits.nvim', tag = 'v1.0.0' })
-- to use Kitty multiplexer support, run the post install hook
use({ 'mrjones2014/smart-splits.nvim', run = './kitty/install-kittens.bash' })
```

With Lazy.nvim:

```lua
{ 'mrjones2014/smart-splits.nvim' }
-- or use a specific version, or a range of versions using lazy.nvim's version API
{ 'mrjones2014/smart-splits.nvim', version = '>=1.0.0' }
-- to use Kitty multiplexer support, run the post install hook
{ 'mrjones2014/smart-splits.nvim', build = './kitty/install-kittens.bash' }
```

## Configuration

You can set ignored `buftype`s or `filetype`s which will be ignored when
figuring out if your cursor is currently at an edge split for resizing.
This is useful in order to ignore "sidebar" type buffers while resizing,
such as [nvim-tree.lua](https://github.com/kyazdani42/nvim-tree.lua)
which tries to maintain its own width unless manually resized. Note that
nothing is ignored when moving between splits, only when resizing.

> [!NOTE]
> smart-splits.nvim does not map any keys on it's own. See [Usage](#usage).

Defaults are shown below:

```lua
require('smart-splits').setup({
  -- Ignored buffer types (only while resizing)
  ignored_buftypes = {
    'nofile',
    'quickfix',
    'prompt',
  },
  -- Ignored filetypes (only while resizing)
  ignored_filetypes = { 'NvimTree' },
  -- the default number of lines/columns to resize by at a time
  default_amount = 3,
  -- Desired behavior when your cursor is at an edge and you
  -- are moving towards that same edge:
  -- 'wrap' => Wrap to opposite side
  -- 'split' => Create a new split in the desired direction
  -- 'stop' => Do nothing
  -- function => You handle the behavior yourself
  -- NOTE: If using a function, the function will be called with
  -- a context object with the following fields:
  -- {
  --    mux = {
  --      type:'tmux'|'wezterm'|'kitty'|'zellij'
  --      current_pane_id():number,
  --      is_in_session(): boolean
  --      current_pane_is_zoomed():boolean,
  --      -- following methods return a boolean to indicate success or failure
  --      current_pane_at_edge(direction:'left'|'right'|'up'|'down'):boolean
  --      next_pane(direction:'left'|'right'|'up'|'down'):boolean
  --      resize_pane(direction:'left'|'right'|'up'|'down'):boolean
  --      split_pane(direction:'left'|'right'|'up'|'down',size:number|nil):boolean
  --    },
  --    direction = 'left'|'right'|'up'|'down',
  --    split(), -- utility function to split current Neovim pane in the current direction
  --    wrap(), -- utility function to wrap to opposite Neovim pane
  -- }
  -- NOTE: `at_edge = 'wrap'` is not supported on Kitty terminal
  -- multiplexer, as there is no way to determine layout via the CLI
  at_edge = 'wrap',
  -- Desired behavior when the current window is floating:
  -- 'previous' => Focus previous Vim window and perform action
  -- 'mux' => Always forward action to multiplexer
  float_win_behavior = 'previous',
  -- when moving cursor between splits left or right,
  -- place the cursor on the same row of the *screen*
  -- regardless of line numbers. False by default.
  -- Can be overridden via function parameter, see Usage.
  move_cursor_same_row = false,
  -- whether the cursor should follow the buffer when swapping
  -- buffers by default; it can also be controlled by passing
  -- `{ move_cursor = true }` or `{ move_cursor = false }`
  -- when calling the Lua function.
  cursor_follows_swapped_bufs = false,
  -- ignore these autocmd events (via :h eventignore) while processing
  -- smart-splits.nvim computations, which involve visiting different
  -- buffers and windows. These events will be ignored during processing,
  -- and un-ignored on completed. This only applies to resize events,
  -- not cursor movement events.
  ignored_events = {
    'BufEnter',
    'WinEnter',
  },
  -- enable or disable a multiplexer integration;
  -- automatically determined, unless explicitly disabled or set,
  -- by checking the $TERM_PROGRAM environment variable,
  -- and the $KITTY_LISTEN_ON environment variable for Kitty.
  -- You can also set this value by setting `vim.g.smart_splits_multiplexer_integration`
  -- before the plugin is loaded (e.g. for lazy environments).
  multiplexer_integration = nil,
  -- disable multiplexer navigation if current multiplexer pane is zoomed
  -- NOTE: This does not work on Zellij as there is no way to determine the
  -- pane zoom state outside of the Zellij Plugin API, which does not apply here
  disable_multiplexer_nav_when_zoomed = true,
  -- Supply a Kitty remote control password if needed,
  -- or you can also set vim.g.smart_splits_kitty_password
  -- see https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.remote_control_password
  kitty_password = nil,
  -- In Zellij, set this to true if you would like to move to the next *tab*
  -- when the current pane is at the edge of the zellij tab/window
  zellij_move_focus_or_tab = false,
  -- default logging level, one of: 'trace'|'debug'|'info'|'warn'|'error'|'fatal'
  log_level = 'info',
})
```

## Usage

### Key Mappings

> [!NOTE]
> The recommended mappings use the Alt/Meta key. In some terminals, such as Alacritty
> and Ghostty, on macOS you will need to set a configuration option for it to treat
> the macOS Option key as Alt.
>
> See: [https://ghostty.org/docs/config/reference#macos-option-as-alt](https://ghostty.org/docs/config/reference#macos-option-as-alt) \
> See: [https://alacritty.org/config-alacritty.html#s20](https://alacritty.org/config-alacritty.html#s20)

```lua
-- recommended mappings
-- resizing splits
-- these keymaps will also accept a range,
-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
vim.keymap.set('n', '<A-h>', require('smart-splits').resize_left)
vim.keymap.set('n', '<A-j>', require('smart-splits').resize_down)
vim.keymap.set('n', '<A-k>', require('smart-splits').resize_up)
vim.keymap.set('n', '<A-l>', require('smart-splits').resize_right)
-- moving between splits
vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
vim.keymap.set('n', '<C-\\>', require('smart-splits').move_cursor_previous)
-- swapping buffers between windows
vim.keymap.set('n', '<leader><leader>h', require('smart-splits').swap_buf_left)
vim.keymap.set('n', '<leader><leader>j', require('smart-splits').swap_buf_down)
vim.keymap.set('n', '<leader><leader>k', require('smart-splits').swap_buf_up)
vim.keymap.set('n', '<leader><leader>l', require('smart-splits').swap_buf_right)
```

### Lua API

```lua
-- resizing splits
-- amount defaults to 3 if not specified
-- use absolute values, no + or -
-- the functions also check for a range,
-- so for example if you bind `<A-h>` to `resize_left`,
-- then `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
require('smart-splits').resize_up(amount)
require('smart-splits').resize_down(amount)
require('smart-splits').resize_left(amount)
require('smart-splits').resize_right(amount)
-- moving between splits
-- You can override config.at_edge and
-- config.move_cursor_same_row via opts
-- See Configuration.
require('smart-splits').move_cursor_up({ same_row = boolean, at_edge = 'wrap' | 'split' | 'stop' })
require('smart-splits').move_cursor_down()
require('smart-splits').move_cursor_left()
require('smart-splits').move_cursor_right()
require('smart-splits').move_cursor_previous()
-- Swapping buffers directionally with the window to the specified direction
require('smart-splits').swap_buf_up()
require('smart-splits').swap_buf_down()
require('smart-splits').swap_buf_left()
require('smart-splits').swap_buf_right()
-- the buffer swap functions can also take an `opts` table to override the
-- default behavior of whether or not the cursor follows the buffer
require('smart-splits').swap_buf_right({ move_cursor = true })
```

### Multiplexer Integrations

`smart-splits.nvim` can also enable seamless navigation between Neovim splits and `tmux`, `zellij`, `wezterm`, or `kitty` panes.
You will need to set up keymaps in your `tmux`, `wezterm`, or `kitty` configs to match the Neovim keymaps.

You can also set the desired multiplexer integration in lazy environments before the plugin is loaded by setting
`vim.g.smart_splits_multiplexer_integration`. The values are the same as described in [Configuration](#configuration).

#### Tmux

You can use the package manager [TPM](https://github.com/tmux-plugins/tpm) to configure your Tmux setup:

> [!NOTE]
> It is recommended to _not_ lazy load `smart-splits.nvim` when using this integration. It depends on the plugin
> setting the `@pane-is-vim` tmux variable, which won't happen until the plugin is loaded.
>
> Currently, jumping to the last viewed pane is not supported. Feel free to submit a PR for it!

```tmux
set -g @plugin 'mrjones2014/smart-splits.nvim'

# Optional configurations with their default values if omitted:

set -g @smart-splits_no_wrap '' # to disable wrapping. (any value disables wrapping)

set -g @smart-splits_move_left_key  'C-h' # key-mapping for navigation.
set -g @smart-splits_move_down_key  'C-j' #  --"--
set -g @smart-splits_move_up_key    'C-k' #  --"--
set -g @smart-splits_move_right_key 'C-l' #  --"--

set -g @smart-splits_resize_left_key  'M-h' # key-mapping for resizing.
set -g @smart-splits_resize_down_key  'M-j' #  --"--
set -g @smart-splits_resize_up_key    'M-k' #  --"--
set -g @smart-splits_resize_right_key 'M-l' #  --"--

set -g @smart-splits_resize_step_size '3' # change the step-size for resizing.
```

Alternatively, add the following snippet to your `~/.tmux.conf`/`~/.config/tmux/tmux.conf` file (customizing the keys and resize amount if desired):

```tmux
# '@pane-is-vim' is a pane-local option that is set by the plugin on load,
# and unset when Neovim exits or suspends; note that this means you'll probably
# not want to lazy-load smart-splits.nvim, as the variable won't be set until
# the plugin is loaded

# Smart pane switching with awareness of Neovim splits.
bind-key -n C-h if -F "#{@pane-is-vim}" 'send-keys C-h'  'select-pane -L'
bind-key -n C-j if -F "#{@pane-is-vim}" 'send-keys C-j'  'select-pane -D'
bind-key -n C-k if -F "#{@pane-is-vim}" 'send-keys C-k'  'select-pane -U'
bind-key -n C-l if -F "#{@pane-is-vim}" 'send-keys C-l'  'select-pane -R'

# Alternatively, if you want to disable wrapping when moving in non-neovim panes, use these bindings
# bind-key -n C-h if -F '#{@pane-is-vim}' { send-keys C-h } { if -F '#{pane_at_left}'   '' 'select-pane -L' }
# bind-key -n C-j if -F '#{@pane-is-vim}' { send-keys C-j } { if -F '#{pane_at_bottom}' '' 'select-pane -D' }
# bind-key -n C-k if -F '#{@pane-is-vim}' { send-keys C-k } { if -F '#{pane_at_top}'    '' 'select-pane -U' }
# bind-key -n C-l if -F '#{@pane-is-vim}' { send-keys C-l } { if -F '#{pane_at_right}'  '' 'select-pane -R' }

# Smart pane resizing with awareness of Neovim splits.
bind-key -n M-h if -F "#{@pane-is-vim}" 'send-keys M-h' 'resize-pane -L 3'
bind-key -n M-j if -F "#{@pane-is-vim}" 'send-keys M-j' 'resize-pane -D 3'
bind-key -n M-k if -F "#{@pane-is-vim}" 'send-keys M-k' 'resize-pane -U 3'
bind-key -n M-l if -F "#{@pane-is-vim}" 'send-keys M-l' 'resize-pane -R 3'

tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if -F \"#{@pane-is-vim}\" 'send-keys C-\\'  'select-pane -l'"
if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if -F \"#{@pane-is-vim}\" 'send-keys C-\\\\'  'select-pane -l'"

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-l' select-pane -R
bind-key -T copy-mode-vi 'C-\' select-pane -l
```

#### Zellij

Zellij support is implemented with help from [vim-zellij-navigator](https://github.com/hiasr/vim-zellij-navigator).
Add the following keymap config to your Zellij KDL config, adjusting the keys you wish to use as necessary.
Consult the documentation from [vim-zellij-navigator](https://github.com/hiasr/vim-zellij-navigator) for more customization options.
No configuration should be needed on the Neovim side.

**Resizing by a specific amount from Neovim and presetting new split size is unsupported.**

> [!NOTE]
> This is an example. It is highly recommended to manually install the plugins and use `MessagePlugin "file:/path/to/plugin.wasm"`
> instead of the GitHub URL!

```kdl
keybinds {
  shared_except "locked" {
    bind "Ctrl h" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "move_focus";
            payload "left";
        };
    }
    bind "Ctrl j" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "move_focus";
            payload "down";
        };
    }
    bind "Ctrl k" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "move_focus";
            payload "up";
        };
    }
    bind "Ctrl l" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "move_focus";
            payload "right";
        };
    }
    bind "Alt h" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "resize";
            payload "left";
        };
    }
    bind "Alt j" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "resize";
            payload "down";
        };
    }
    bind "Alt k" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "resize";
            payload "up";
        };
    }
    bind "Alt l" {
        MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.2.1/vim-zellij-navigator.wasm" {
            name "resize";
            payload "right";
        };
    }
  }
}
```

##### Troubleshooting

If you are able to move between and resize Zellij splits, but not Neovim splits, it could be that the `zellij` command is not
on the `$PATH` that is made available to the Zellij process itself. The `vim-zellij-navigator` plugin currently uses `zellij action list-clients`
to determine if the current pane is running Neovim (this will go away in a future release when that information is made available directly via the Zellij plugin API).

To troubleshoot this, from within your Zellij session, you can run `zellij run -- env` to see Zellij's current environment, which should include it's `$PATH` variable.

#### Wezterm

> [!NOTE]
> It is recommended _not to lazy load_ `smart-splits.nvim` if using the Wezterm integration.
> If you need to lazy load, you need to use a different `is_vim()` implementation below.
> The plugin is small, and smart about not loading modules unnecessarily, so it should
> have minimal impact on your startup time. It adds about 0.07ms on my setup.

> [!NOTE]
> Pane resizing currently requires a nightly build of Wezterm.
> Check the output of `wezterm cli adjust-pane-size --help` to see if your build supports it; if not,
> you can check how to obtain a nightly build by [following the instructions here](https://wezfurlong.org/wezterm/installation.html).

First, ensure that the `wezterm` CLI is on your `$PATH`, as the CLI is used by the integration.

Then, if you're on Wezterm nightly, you can use Wezterm's [experimental plugin loader](https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd):

```lua
local wezterm = require('wezterm')
local smart_splits = wezterm.plugin.require('https://github.com/mrjones2014/smart-splits.nvim')
local config = wezterm.config_builder()
-- you can put the rest of your Wezterm config here
smart_splits.apply_to_config(config, {
  -- the default config is here, if you'd like to use the default keys,
  -- you can omit this configuration table parameter and just use
  -- smart_splits.apply_to_config(config)

  -- directional keys to use in order of: left, down, up, right
  direction_keys = { 'h', 'j', 'k', 'l' },
  -- if you want to use separate direction keys for move vs. resize, you
  -- can also do this:
  direction_keys = {
    move = { 'h', 'j', 'k', 'l' },
    resize = { 'LeftArrow', 'DownArrow', 'UpArrow', 'RightArrow' },
  },
  -- modifier keys to combine with direction_keys
  modifiers = {
    move = 'CTRL', -- modifier to use for pane movement, e.g. CTRL+h to move left
    resize = 'META', -- modifier to use for pane resize, e.g. META+h to resize to the left
  },
  -- log level to use: info, warn, error
  log_level = 'info',
})
```

Otherwise, add the following snippet to your `~/.config/wezterm/wezterm.lua`:

```lua
local w = require('wezterm')

-- if you are *NOT* lazy-loading smart-splits.nvim (recommended)
local function is_vim(pane)
  -- this is set by the plugin, and unset on ExitPre in Neovim
  return pane:get_user_vars().IS_NVIM == 'true'
end

-- if you *ARE* lazy-loading smart-splits.nvim (not recommended)
-- you have to use this instead, but note that this will not work
-- in all cases (e.g. over an SSH connection). Also note that
-- `pane:get_foreground_process_name()` can have high and highly variable
-- latency, so the other implementation of `is_vim()` will be more
-- performant as well.
local function is_vim(pane)
  -- This gsub is equivalent to POSIX basename(3)
  -- Given "/foo/bar" returns "bar"
  -- Given "c:\\foo\\bar" returns "bar"
  local process_name = string.gsub(pane:get_foreground_process_name(), '(.*[/\\])(.*)', '%2')
  return process_name == 'nvim' or process_name == 'vim'
end

local direction_keys = {
  h = 'Left',
  j = 'Down',
  k = 'Up',
  l = 'Right',
}

local function split_nav(resize_or_move, key)
  return {
    key = key,
    mods = resize_or_move == 'resize' and 'META' or 'CTRL',
    action = w.action_callback(function(win, pane)
      if is_vim(pane) then
        -- pass the keys through to vim/nvim
        win:perform_action({
          SendKey = { key = key, mods = resize_or_move == 'resize' and 'META' or 'CTRL' },
        }, pane)
      else
        if resize_or_move == 'resize' then
          win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
        end
      end
    end),
  }
end

return {
  keys = {
    -- move between split panes
    split_nav('move', 'h'),
    split_nav('move', 'j'),
    split_nav('move', 'k'),
    split_nav('move', 'l'),
    -- resize panes
    split_nav('resize', 'h'),
    split_nav('resize', 'j'),
    split_nav('resize', 'k'),
    split_nav('resize', 'l'),
  },
}
```

#### Kitty

> [!NOTE]
> It is recommended _not to lazy load_ `smart-splits.nvim` if using the Kitty integration,
> since it depends on the plugin setting the `IS_NVIM` Kitty user variable on startup.
> The plugin is small, and smart about not loading modules unnecessarily, so it should
> have minimal impact on your startup time. It adds about 0.07ms on my setup.

> [!NOTE]
> The `config.at_edge = 'wrap'` option is not supoprted in Kitty terminal multiplexer due to inability to determine
> pane layout from CLI.

By default the plugin sets a kitty user-var `IS_NVIM` when it loads. You can take advantage of this together with kittys
[conditional mappings feature](https://sw.kovidgoyal.net/kitty/mapping/#conditional-mappings-depending-on-the-state-of-the-focused-window) to use the same keybind for both kitty and neovim.

Add the following snippet to `~/.config/kitty/kitty.conf`, adjusting the keymaps and resize amount as desired.

```
map ctrl+j neighboring_window down
map ctrl+k neighboring_window up
map ctrl+h neighboring_window left
map ctrl+l neighboring_window right

# Unset the mapping to pass the keys to neovim
map --when-focus-on var:IS_NVIM ctrl+j
map --when-focus-on var:IS_NVIM ctrl+k
map --when-focus-on var:IS_NVIM ctrl+h
map --when-focus-on var:IS_NVIM ctrl+l

# the 3 here is the resize amount, adjust as needed
map alt+j kitten relative_resize.py down  3
map alt+k kitten relative_resize.py up    3
map alt+h kitten relative_resize.py left  3
map alt+l kitten relative_resize.py right 3

map --when-focus-on var:IS_NVIM alt+j
map --when-focus-on var:IS_NVIM alt+k
map --when-focus-on var:IS_NVIM alt+h
map --when-focus-on var:IS_NVIM alt+l
```

Then, you must allow Kitty to listen for remote commands on a socket. You can do this
either by running Kitty with the following command:

```bash
# For linux only:
kitty -o allow_remote_control=yes --single-instance --listen-on unix:@mykitty

# Other unix systems:
kitty -o allow_remote_control=yes --single-instance --listen-on unix:/tmp/mykitty
```

Or, by adding the following to `~/.config/kitty/kitty.conf`:

```
# For linux only:
allow_remote_control yes
listen_on unix:@mykitty

# Other unix systems:
allow_remote_control yes
listen_on unix:/tmp/mykitty
```

##### Credits

Thanks @knubie for inspiration for the Kitty implementation from [vim-kitty-navigator](https://github.com/knubie/vim-kitty-navigator).

Thanks to @chancez for the relative resize [Python kitten](https://github.com/chancez/dotfiles/blob/badc69d3895a6a942285126b8c372a55d77533e1/kitty/.config/kitty/relative_resize.py).

### Multiplexer Lua API

You can directly access the multiplexer API for scripting purposes as well.
To get a handle to the current multiplexer backend, you can do:

```lua
local mux = require('smart-splits.mux').get()
```

This returns the currently enabled multiplexer backend, or `nil` if none is currently in use.
The API offers the following methods:

```lua
local mux = require('smart-splits.mux').get()
-- mux matches the following type annotations
---@class SmartSplitsMultiplexer
---@field current_pane_id fun():number|nil
---@field current_pane_at_edge fun(direction:'left'|'right'|'up'|'down'):boolean
---@field is_in_session fun():boolean
---@field current_pane_is_zoomed fun():boolean
---@field next_pane fun(direction:'left'|'right'|'up'|'down'):boolean
---@field resize_pane fun(direction:'left'|'right'|'up'|'down', amount:number):boolean
---@field split_pane fun(direction:'left'|'right'|'up'|'down',size:number|nil):boolean
---@field type 'tmux'|'wezterm'|'kitty'|'zellij'
```

### Persistent Resize Mode

Previously, `smart-splits.nvim` included a "persistent resize mode" feature, which temporarily allowed you to
resize windows by pressing just your directional keys without a modifier, until exiting resize mode. This feature
had a lot of bugs and was too much of a maintenance burden, and is much better handled by other plugins that are
designed to do that sort of thing, and the feature was therefore removed.

Instead, you should use something like [submode.nvim](https://github.com/pogyomo/submode.nvim) with a configuration like:

```lua
{
  'mrjones2014/smart-splits.nvim',
  event = 'VeryLazy',
  dependencies = {
    'pogyomo/submode.nvim',
  },
  config = function()
    -- Resize
    local submode = require 'submode'
    submode.create('WinResize', {
      mode = 'n',
      enter = '<C-w>r',
      leave = { '<Esc>', 'q', '<C-c>' },
      hook = {
        on_enter = function()
          vim.notify 'Use { h, j, k, l } or { <Left>, <Down>, <Up>, <Right> } to resize the window'
        end,
        on_leave = function()
          vim.notify ''
        end,
      },
      default = function(register)
        register('h', require('smart-splits').resize_left, { desc = 'Resize left' })
        register('j', require('smart-splits').resize_down, { desc = 'Resize down' })
        register('k', require('smart-splits').resize_up, { desc = 'Resize up' })
        register('l', require('smart-splits').resize_right, { desc = 'Resize right' })
        register('<Left>', require('smart-splits').resize_left, { desc = 'Resize left' })
        register('<Down>', require('smart-splits').resize_down, { desc = 'Resize down' })
        register('<Up>', require('smart-splits').resize_up, { desc = 'Resize up' })
        register('<Right>', require('smart-splits').resize_right, { desc = 'Resize right' })
      end,
    })
  end,
}
```

Special thank you to [@drowining-cat](https://github.com/drowning-cat) for putting this example together.

Other alternative plugins to do this include:

- [hydra.nvim](https://github.com/anuvyklack/hydra.nvim)
- [mini.clue](https://github.com/echasnovski/mini.nvim/blob/main/doc/mini-clue.txt#L357)
