local M = {}

---@param msg string
---@param ... any
local function info(msg, ...)
  vim.health.info(msg:format(...))
end

---@param msg string
---@param ... any
local function ok(msg, ...)
  vim.health.ok(msg:format(...))
end

---@param msg string
---@param ... any
local function warn(msg, ...)
  vim.health.warn(msg:format(...))
end

---@param msg string
---@param ... any
local function error(msg, ...)
  vim.health.error(msg:format(...))
end

local function check_config()
  local Config = require('smart-splits.config')

  local issues = Config.issues()
  if #issues == 0 then
    ok('config is valid')
  else
    for _, issue in ipairs(issues) do
      warn('%s', issue)
    end
  end

  local at_edge = Config.move.at_edge
  info('move.at_edge: %s', type(at_edge) == 'function' and '<function>' or vim.inspect(at_edge))
  info('move.same_row: %s', vim.inspect(Config.move.same_row))
  info('resize.amount: %s', vim.inspect(Config.resize.amount))
  info('swap.move_cursor: %s', vim.inspect(Config.swap.move_cursor))

  for _, feature in ipairs({ 'resize', 'move' }) do
    local buftypes, filetypes = Config.ignores(feature)
    info('%s.ignored_buftypes: %s', feature, table.concat(buftypes, ', '))
    info('%s.ignored_filetypes: %s', feature, table.concat(filetypes, ', '))
  end
end

local function check_log()
  local Config = require('smart-splits.config')
  info('log.level: %s', Config.log.level)

  if not Config.log.file then
    info('log.file: disabled')
    return
  end

  local path = require('smart-splits.log').file_path()
  if path then
    ok('log file: %s', path)
  else
    warn('log file could not be opened, check that `log.file` points somewhere writable')
  end
end

---Report how each configured backend fared, and collect the ones that validated
---so their own health checks can run.
---@return SmartSplitsBackend[] candidates
local function check_backends()
  local Backend = require('smart-splits.backend')
  local Config = require('smart-splits.config')

  vim.health.start('smart-splits.nvim: backends')
  info('supported protocol versions: %s', table.concat(vim.tbl_map(tostring, Backend.SUPPORTED_VERSIONS), ', '))

  if Config.mux.backend == nil then
    info('no backend configured, window movement stops at the edges of Neovim')
    return {}
  end

  -- idempotent, so this returns the existing result if anything has already
  -- resolved; it only does real work when `:checkhealth` is the first thing to
  -- ask, and then the report below describes that same resolution
  Backend.resolve()

  ---@type SmartSplitsBackend[]
  local candidates = {}
  for _, entry in ipairs(Backend.report()) do
    if entry.backend and entry.status == 'resolved' then
      ok('%s: in use, protocol version %s', entry.spec, entry.backend.protocol_version)
    elseif entry.status == 'skipped' then
      info('%s: %s', entry.spec, entry.reason)
    else
      error('%s: %s', entry.spec, entry.reason)
    end
    if entry.backend then
      table.insert(candidates, entry.backend)
    end
  end

  return candidates
end

---Run each backend's own health check under a header emitted here, so backends
---never have to call `vim.health.start` themselves. Every candidate that
---validated gets a turn, not just the one in use, otherwise the backend that
---did not activate has no way to explain why.
---@param candidates SmartSplitsBackend[]
local function check_backend_health(candidates)
  for _, backend in ipairs(candidates) do
    if backend.health then
      vim.health.start(("smart-splits.nvim: backend '%s'"):format(backend.name))
      local success, err = pcall(backend.health)
      if not success then
        error('health() errored: %s', err)
      end

      local detected, result = pcall(backend.detect)
      if detected and result ~= true then
        info('detect() currently returns false')
      end
    end
  end
end

---Entry point for `:checkhealth smart-splits`.
function M.check()
  vim.health.start('smart-splits.nvim')

  if vim.fn.has('nvim-0.11') == 0 then
    error('Neovim 0.11 or newer is required, found %s', tostring(vim.version()))
    return
  end
  ok('Neovim %s', tostring(vim.version()))

  check_config()
  check_log()
  check_backend_health(check_backends())
end

return M
