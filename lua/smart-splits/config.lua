local Types = require('smart-splits.types')
local AtEdgeBehavior = Types.AtEdgeBehavior

---A list of buftypes or filetypes, so a plain `string[]` satisfies it. Given on
---its own it replaces the top level list of the same name; set `inherit = true`
---to union with that list instead.
---@class SmartSplitsIgnoreList
---@field inherit boolean|nil union with the top level list instead of replacing it
---@field [integer] string

---@class SmartSplitsResizeConfig
---@field amount number cells to resize by, multiplied by `v:count1`
---@field ignored_events string[] events to add to `eventignore` while resizing
---@field ignored_buftypes SmartSplitsIgnoreList|nil
---@field ignored_filetypes SmartSplitsIgnoreList|nil

---@class SmartSplitsMoveConfig
---@field at_edge SmartSplitsAtEdgeBehavior what to do when there is no window and no pane in the given direction
---@field same_row boolean keep the cursor on the same screen row when moving horizontally
---@field ignored_buftypes SmartSplitsIgnoreList|nil
---@field ignored_filetypes SmartSplitsIgnoreList|nil

---@class SmartSplitsSwapConfig
---@field move_cursor boolean follow the buffer into its new window

---@class SmartSplitsMuxConfig
---@field backend SmartSplitsBackendConfig|nil backend, list of backends in priority order, or a function returning either
---@field warn_if_unusable boolean warn when backends are configured but none of them detected

---@class SmartSplitsLogConfig
---@field level SmartSplitsLogLevel
---@field file boolean|string `true` for the default path, a string for a custom one, `false` to disable

---@class SmartSplitsDiagnosticConfig
---@field enabled boolean enable or disable all doagnostic messages; default `true`
---@field slow_threshold number in milliseconcds, time at which a backend operation is considered slow

---@class SmartSplitsConfig
---@field ignored_buftypes string[]
---@field ignored_filetypes string[]
---@field resize SmartSplitsResizeConfig
---@field move SmartSplitsMoveConfig
---@field swap SmartSplitsSwapConfig
---@field mux SmartSplitsMuxConfig
---@field log SmartSplitsLogConfig
---@field diagnostic SmartSplitsDiagnosticConfig

---@class SmartSplitsConfigModule: SmartSplitsConfig
---@field setup fun(opts: table|nil)
---@field ignores fun(feature: 'resize'|'move'): string[], string[]
---@field issues fun(): string[]
---@field private reset fun()

---@type SmartSplitsConfig
local defaults = {
  ignored_buftypes = { 'nofile', 'quickfix', 'prompt' },
  ignored_filetypes = { 'NvimTree' },
  resize = {
    amount = 3,
    ignored_events = { 'BufEnter', 'WinEnter' },
  },
  move = {
    at_edge = AtEdgeBehavior.wrap,
    same_row = false,
  },
  swap = {
    move_cursor = false,
  },
  mux = {
    warn_if_unusable = true,
  },
  log = {
    level = 'info',
    file = true,
  },
  diagnostic = {
    enabled = false,
    slow_threshold = 100,
  },
}

---Every option the user may set. Spelled out rather than derived from
---`defaults`, because options that default to `nil` have no key to derive from.
---`true` marks a top level option, a list names the keys of a section.
---@type table<string, true|string[]>
local schema = {
  ignored_buftypes = true,
  ignored_filetypes = true,
  resize = { 'amount', 'ignored_events', 'ignored_buftypes', 'ignored_filetypes' },
  move = { 'at_edge', 'same_row', 'ignored_buftypes', 'ignored_filetypes' },
  swap = { 'move_cursor' },
  mux = { 'backend', 'warn_if_unusable' },
  log = { 'level', 'file' },
  diagnostic = { 'enabled', 'slow_threshold' },
}

---v2 keys and where they went. Due for removal some time after v3 ships.
---@type table<string, string>
local renamed = {
  default_amount = 'resize.amount',
  ignored_events = 'resize.ignored_events',
  move_cursor_same_row = 'move.same_row',
  at_edge = 'move.at_edge',
  cursor_follows_swapped_bufs = 'swap.move_cursor',
  multiplexer_integration = 'mux.backend',
  log_level = 'log.level',
}

---v2 keys with no v3 equivalent, and why.
---@type table<string, string>
local removed = {
  disable_multiplexer_nav_when_zoomed = 'zoom is handled inside the backend now, configure it there',
  float_win_behavior = 'floating windows always focus the previous window',
  wezterm_cli_path = 'moved to the wezterm backend plugin',
  kitty_password = 'moved to the kitty backend plugin',
  zellij_move_focus_or_tab = 'moved to the zellij backend plugin',
  tmux_integration = 'removed in v2, use mux.backend',
  wrap_at_edge = 'removed in v2, use move.at_edge',
}

local options = vim.deepcopy(defaults)

---Problems found during the last `setup()`, reported at startup and again in
---`:checkhealth`.
---@type string[]
local issues = {}

---Merge user options over the defaults. Lists are replaced wholesale rather
---than merged index by index, which is what `vim.tbl_deep_extend` would do and
---why it is not used here: extending `{'nofile','quickfix','prompt'}` with
---`{'terminal'}` would silently yield `{'terminal','quickfix','prompt'}`.
---@param into table
---@param from table
local function merge(into, from)
  for key, value in pairs(from) do
    if type(value) == 'table' and type(into[key]) == 'table' and not vim.islist(value) then
      merge(into[key], value)
    else
      into[key] = value
    end
  end
end

---@param path string the option path the user wrote
local function unknown_key(path)
  table.insert(issues, ('`%s` is not a valid option, see :h smart-splits-configuration'):format(path))
end

---@param opts table the raw user table
local function check_keys(opts)
  for key, value in pairs(opts) do
    local nested = schema[key]
    if renamed[key] then
      table.insert(issues, ('`%s` moved to `%s`'):format(key, renamed[key]))
    elseif removed[key] then
      table.insert(issues, ('`%s` was removed, %s'):format(key, removed[key]))
    elseif nested == nil then
      unknown_key(key)
    elseif type(nested) == 'table' and type(value) == 'table' then
      for nested_key, _ in pairs(value) do
        if type(nested_key) == 'string' and not vim.tbl_contains(nested, nested_key) then
          unknown_key(('%s.%s'):format(key, nested_key))
        end
      end
    end
  end
end

---Check the options with a small set of valid values. An invalid value falls
---back to its default rather than raising, so a typo cannot leave the editor
---unusable.
local function check_values()
  local Log = require('smart-splits.log')

  local at_edge = options.move.at_edge
  if type(at_edge) ~= 'function' and not AtEdgeBehavior[at_edge] then
    table.insert(
      issues,
      ('`move.at_edge` must be "stop", "wrap", "split" or a function, got %s'):format(vim.inspect(at_edge))
    )
    options.move.at_edge = defaults.move.at_edge
  end

  if type(options.resize.amount) ~= 'number' then
    table.insert(issues, ('`resize.amount` must be a number, got %s'):format(vim.inspect(options.resize.amount)))
    options.resize.amount = defaults.resize.amount
  end

  if not vim.tbl_contains(Log.levels, options.log.level) then
    table.insert(
      issues,
      ('`log.level` must be one of %s, got %s'):format(table.concat(Log.levels, ', '), vim.inspect(options.log.level))
    )
    options.log.level = defaults.log.level
  end

  if type(options.log.file) ~= 'boolean' and type(options.log.file) ~= 'string' then
    table.insert(issues, ('`log.file` must be a boolean or a string, got %s'):format(vim.inspect(options.log.file)))
    options.log.file = defaults.log.file
  end

  local backend_type = type(options.mux.backend)
  if
    options.mux.backend ~= nil
    and backend_type ~= 'string'
    and backend_type ~= 'table'
    and backend_type ~= 'function'
  then
    table.insert(issues, ('`mux.backend` must be a string, table, list or function, got %s'):format(backend_type))
    options.mux.backend = nil
  end
end

local Config = {}

---Buftypes and filetypes to ignore for the given feature. A feature level list
---replaces the top level one, or unions with it when it sets `inherit = true`.
---@param feature 'resize'|'move'
---@return string[] buftypes
---@return string[] filetypes
function Config.ignores(feature)
  local section = feature == 'resize' and options.resize or options.move

  ---@param key 'ignored_buftypes'|'ignored_filetypes'
  ---@return string[]
  local function resolve(key)
    local override = section[key]
    if not override then
      return options[key]
    end

    -- drop the `inherit` flag, leaving only the names
    ---@type string[]
    local names = {}
    for _, value in ipairs(override) do
      table.insert(names, value)
    end

    if not override.inherit then
      return names
    end
    return vim.list_extend(vim.list_extend({}, options[key]), names)
  end

  return resolve('ignored_buftypes'), resolve('ignored_filetypes')
end

---Problems found in the user's config, if any.
---@return string[]
function Config.issues()
  return issues
end

---Merge user options over the defaults and report anything wrong with them.
---Always merges from the defaults rather than from the previous result, so
---calling this more than once does not accumulate.
---@param opts table|nil
function Config.setup(opts)
  opts = opts or {}
  local previous_backend = options.mux.backend

  options = vim.deepcopy(defaults)
  issues = {}
  merge(options, opts)

  check_keys(opts)
  check_values()

  require('smart-splits.log').reset()

  if #issues > 0 then
    require('smart-splits.log').notify(
      vim.log.levels.WARN,
      'problems in your config, see :checkhealth smart-splits\n  %s',
      table.concat(issues, '\n  ')
    )
  end

  -- resolve here rather than from an autocmd: the plugin may be lazy loaded, in
  -- which case `plugin/smart-splits.lua` does not run until well after `VimEnter`
  local Backend = require('smart-splits.backend')
  if previous_backend ~= options.mux.backend then
    Backend.reset()
  end
  Backend.resolve()
end

---Restore the defaults. Useful for testing.
---@private
function Config.reset()
  options = vim.deepcopy(defaults)
  issues = {}
end

setmetatable(Config, {
  __index = function(_, key)
    return options[key]
  end,
  __newindex = function(_, key, value)
    options[key] = value
  end,
})

---@cast Config SmartSplitsConfigModule
return Config
