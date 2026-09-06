---The resolved options for a move, as core worked them out from the user's
---config and whatever they passed for this call. Fields are optional so the
---functions can be called by hand; fall back to your own defaults for anything
---absent. Later protocol versions may add fields, so ignore unknown ones.
---@class SmartSplitsBackendMoveOpts
---@field at_edge 'stop'|'wrap'|'split'|nil what to do when there is no pane in the given direction

---@class SmartSplitsBackendResizeOpts
---@field amount number|nil cells to resize by, already multiplied by `v:count1`

---A multiplexer backend. Backends live in their own plugins, core ships none.
---Only `name`, `protocol_version`, `detect` and `move` are required. Omit
---`resize` entirely if the multiplexer cannot do it; core checks whether the
---function is present rather than asking for a capability table.
---
---Every operation takes `(direction, opts)`. Core always passes a table, but the
---parameter is optional so the functions stay pleasant to call by hand.
---
---`activate()` is core's signal that this backend won, and is the only place
---initialization work belongs. A backend is free to also expose a `setup()` for
---its own users and plugin managers, but that is the backend's own business:
---core never calls it and the protocol says nothing about it.
---@class SmartSplitsBackend
---@field name string human readable name, used in logs and `:checkhealth`
---@field protocol_version number major protocol version this backend implements
---@field detect fun():boolean is this multiplexer usable right now? must be cheap and free of side effects
---@field move fun(direction: SmartSplitsDirection, opts?: SmartSplitsBackendMoveOpts):boolean move focus one pane, `true` if handled
---@field resize? fun(direction: SmartSplitsDirection, opts?: SmartSplitsBackendResizeOpts):boolean resize the current pane, `true` if handled
---@field activate? fun() called once, when this backend is the one selected; where initialization work belongs
---@field health? fun() called during `:checkhealth smart-splits`, under a header emitted by core
---@field slow_threshold? number configure the threshold, in milliseconds, at which a backend operation should be considered slow and log a warning; default 100ms

---@alias SmartSplitsBackendSpec SmartSplitsBackend|string

---What `config.mux.backend` accepts: one backend, several in priority order, or
---a function returning either.
---@alias SmartSplitsBackendConfig SmartSplitsBackendSpec|SmartSplitsBackendSpec[]|fun():SmartSplitsBackendSpec|SmartSplitsBackendSpec[]

---Current protocol version. A backend declares the major version it implements
---and core refuses to load anything outside `SUPPORTED_VERSIONS`.
local PROTOCOL_VERSION = 3

---Versions core can talk to. A set rather than a single number, so a future
---protocol bump can keep accepting older backends for a release or two instead
---of breaking every backend on the same day.
local SUPPORTED_VERSIONS = { 3 }

---Backend operations run on every keypress that reaches a window edge, so a
---backend that shells out without a timeout will freeze the editor. Core cannot
---impose one, but it can name the culprit.
local DEFAULT_SLOW_MS = 100

local REQUIRED = {
  name = 'string',
  protocol_version = 'number',
  detect = 'function',
  move = 'function',
}

local OPTIONAL = {
  resize = 'function',
  activate = 'function',
  health = 'function',
  slow_threshold = 'number',
}

---How a candidate backend fared during resolution.
---@class SmartSplitsBackendReportEntry
---@field spec string name of the module, or of the backend itself when given inline
---@field status 'resolved'|'skipped'|'invalid'
---@field reason string
---@field backend SmartSplitsBackend|nil set when the candidate validated, whether or not it won

---@class SmartSplitsBackendModule
local M = {}

M.PROTOCOL_VERSION = PROTOCOL_VERSION
M.SUPPORTED_VERSIONS = SUPPORTED_VERSIONS

---@type SmartSplitsBackend|nil
local resolved
local attempted = false

---@type SmartSplitsBackendReportEntry[]
local report = {}

---@param spec SmartSplitsBackendSpec
---@return string
local function spec_name(spec)
  if type(spec) == 'string' then
    return spec
  end
  return type(spec.name) == 'string' and spec.name or vim.inspect(spec)
end

---@param backend table
---@return string|nil error
local function validate(backend)
  for field, expected in pairs(REQUIRED) do
    local actual = type(backend[field])
    if backend[field] == nil then
      return ('missing required field `%s`'):format(field)
    elseif actual ~= expected then
      return ('field `%s` must be a %s, got %s'):format(field, expected, actual)
    end
  end

  for field, expected in pairs(OPTIONAL) do
    if backend[field] ~= nil and type(backend[field]) ~= expected then
      return ('field `%s` must be a %s, got %s'):format(field, expected, type(backend[field]))
    end
  end

  if not vim.tbl_contains(SUPPORTED_VERSIONS, backend.protocol_version) then
    return ('implements protocol version %s, this version of smart-splits.nvim supports %s'):format(
      backend.protocol_version,
      table.concat(vim.tbl_map(tostring, SUPPORTED_VERSIONS), ', ')
    )
  end

  return nil
end

---Turn whatever the user configured into a flat list of candidates.
---@return SmartSplitsBackendSpec[]
local function candidates()
  local configured = require('smart-splits.config').mux.backend
  if type(configured) == 'function' then
    local ok, result = pcall(configured)
    if not ok then
      require('smart-splits.log').error('`mux.backend` function errored: %s', result)
      return {}
    end
    configured = result
  end

  if configured == nil then
    return {}
  end
  if type(configured) == 'string' then
    return { configured }
  end
  if vim.islist(configured) then
    return configured
  end
  return { configured }
end

---Load a candidate and check it against the protocol.
---@param spec SmartSplitsBackendSpec
---@return SmartSplitsBackend|nil backend
---@return string|nil error
local function load(spec)
  if type(spec) ~= 'string' then
    local err = validate(spec)
    if err then
      return nil, err
    end
    return spec, nil
  end

  local ok, module = pcall(require, spec)
  if not ok then
    return nil, ('could not be required: %s'):format(module)
  end
  if type(module) ~= 'table' then
    return nil, ('module returned a %s, expected a table'):format(type(module))
  end

  local err = validate(module)
  if err then
    return nil, err
  end
  return module, nil
end

---Pick the first configured backend that detects. Runs once; later calls return
---the cached result. Called from `setup()`, from every delegated operation, and
---from `:checkhealth`, so that resolution has happened by the time anything
---needs it no matter how the plugin was loaded.
---@return SmartSplitsBackend|nil
function M.resolve()
  if attempted then
    return resolved
  end
  attempted = true

  local Config = require('smart-splits.config')
  local Log = require('smart-splits.log')
  local specs = candidates()

  for _, spec in ipairs(specs) do
    local name = spec_name(spec)
    local backend, err = load(spec)
    if not backend then
      -- always surfaced, even with warn_if_unusable off: that option means "I am
      -- sometimes outside my multiplexer", not "hide my broken backend"
      Log.notify(vim.log.levels.ERROR, 'backend `%s` %s, see :checkhealth smart-splits', name, err)
      table.insert(report, { spec = name, status = 'invalid', reason = err })
    else
      local ok, detected = pcall(backend.detect)
      if not ok then
        Log.notify(vim.log.levels.ERROR, 'backend `%s` detect() errored: %s', name, detected)
        table.insert(report, { spec = name, status = 'invalid', reason = ('detect() errored: %s'):format(detected) })
      elseif detected ~= true then
        Log.debug('backend `%s` detect() returned false, skipping', name)
        table.insert(report, { spec = name, status = 'skipped', reason = 'detect() returned false', backend = backend })
      else
        -- `activate()`, never `setup()`: a backend's `setup()` is not part of
        -- the protocol, it belongs to its own users and plugin managers and gets
        -- called whether or not the backend ends up being the one in use
        if backend.activate then
          local activate_ok, activate_err = pcall(backend.activate)
          if not activate_ok then
            Log.error('backend `%s` activate() errored: %s', name, activate_err)
          end
        end
        resolved = backend
        table.insert(report, { spec = name, status = 'resolved', reason = 'detect() returned true', backend = backend })
        Log.debug('resolved backend `%s`', name)
        return resolved
      end
    end
  end

  if #specs > 0 and Config.mux.warn_if_unusable then
    Log.notify(vim.log.levels.WARN, 'none of the configured backends detected, falling back to plain window movement')
  end

  return nil
end

---Forget the resolved backend and its report, so the next `resolve()` starts
---over. Called when `mux.backend` changes, and from tests.
function M.reset()
  resolved = nil
  attempted = false
  report = {}
end

---What happened to each configured backend during resolution. Recorded once, at
---resolution, so that `:checkhealth` can describe the backend actually in use
---rather than rerunning `detect()` and possibly reaching a different answer.
---@return SmartSplitsBackendReportEntry[]
function M.report()
  return report
end

---@type table<string, boolean>
local reported_errors = {}

---Call an operation on the resolved backend.
---@param op 'move'|'resize'
---@param ... any
---@return boolean handled
local function call(op, ...)
  local backend = M.resolve()
  if not backend or not backend[op] then
    return false
  end

  local Log = require('smart-splits.log')
  local start = vim.uv.hrtime()
  local ok, result = pcall(backend[op], ...)
  local elapsed = (vim.uv.hrtime() - start) / 1e6

  local slow_threshold = backend.slow_threshold
  if type(slow_threshold) ~= 'number' then
    slow_threshold = DEFAULT_SLOW_MS
  end
  if elapsed > slow_threshold then
    Log.warn('backend `%s` %s() took %.1fms, this runs on every keypress at an edge', backend.name, op, elapsed)
  end

  if not ok then
    local key = ('%s.%s.%s'):format(backend.name, op, result)
    if not reported_errors[key] then
      reported_errors[key] = true
      Log.error('backend `%s` %s() errored: %s', backend.name, op, result)
    end
    return false
  end

  -- a backend that forgets to return gets `false`, never a silent "handled"
  return result == true
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsBackendMoveOpts|nil
---@return boolean handled
function M.move(direction, opts)
  return call('move', direction, opts or {})
end

---@param direction SmartSplitsDirection
---@param opts SmartSplitsBackendResizeOpts|nil
---@return boolean handled
function M.resize(direction, opts)
  return call('resize', direction, opts or {})
end

return M
