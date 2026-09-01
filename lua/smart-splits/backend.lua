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
local SLOW_MS = 100

local REQUIRED = {
  name = 'string',
  protocol_version = 'number',
  detect = 'function',
  move = 'function',
}

local OPTIONAL = {
  resize = 'function',
  split = 'function',
  setup = 'function',
  health = 'function',
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
        if backend.setup then
          local setup_ok, setup_err = pcall(backend.setup)
          if not setup_ok then
            Log.error('backend `%s` setup() errored: %s', name, setup_err)
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
---@param op 'move'|'resize'|'split'
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

  if elapsed > SLOW_MS then
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
---@param opts SmartSplitsMoveOptions
---@return boolean handled
function M.move(direction, opts)
  return call('move', direction, opts)
end

---@param direction SmartSplitsDirection
---@param amount number
---@return boolean handled
function M.resize(direction, amount)
  return call('resize', direction, amount)
end

---@param direction SmartSplitsDirection
---@return boolean handled
function M.split(direction)
  return call('split', direction)
end

return M
