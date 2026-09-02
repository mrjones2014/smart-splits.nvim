---@alias SmartSplitsLogLevel 'trace'|'debug'|'info'|'warn'|'error'

---@type SmartSplitsLogLevel[]
local LEVELS = { 'trace', 'debug', 'info', 'warn', 'error' }

---@type table<SmartSplitsLogLevel, number>
local LEVEL_INDEX = {}
for idx, level in ipairs(LEVELS) do
  LEVEL_INDEX[level] = idx
end

---@type table<SmartSplitsLogLevel, string>
local HIGHLIGHTS = {
  trace = 'Comment',
  debug = 'Comment',
  info = 'None',
  warn = 'WarningMsg',
  error = 'ErrorMsg',
}

local PREFIX = '[smart-splits.nvim] '

---@class SmartSplitsLogger
local M = {}

---@type SmartSplitsLogLevel[]
M.levels = LEVELS

---Messages already echoed this session, keyed by the formatted message. A
---backend that fails on every keypress would otherwise flood the message area,
---so the echo happens once while the log file keeps every occurrence.
---@type table<string, boolean>
local echoed = {}

---@type string|nil
local resolved_path
local resolved_path_failed = false

---The log file path, creating its parent directory the first time. Returns
---`nil` when file logging is off, or when the directory cannot be created.
---@return string|nil
function M.file_path()
  if resolved_path_failed then
    return nil
  end
  if resolved_path then
    return resolved_path
  end

  local file = require('smart-splits.config').log.file
  if not file then
    return nil
  end

  ---@type string
  local path
  if type(file) == 'string' then
    path = vim.fn.expand(file)
  else
    path = vim.fs.joinpath(vim.fn.stdpath('log') --[[@as string]], 'smart-splits.log')
  end

  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, 'p') == 0 then
    resolved_path_failed = true
    return nil
  end

  resolved_path = path
  return resolved_path
end

---@param level SmartSplitsLogLevel
---@return boolean
local function enabled(level)
  local configured = LEVEL_INDEX[require('smart-splits.config').log.level] or LEVEL_INDEX.info
  return LEVEL_INDEX[level] >= configured
end

---@param path string
---@param line string
local function append(path, line)
  vim.uv.fs_open(path, 'a', 420, function(err, fd)
    if err or not fd then
      return
    end
    vim.uv.fs_write(fd, line, -1, function()
      vim.uv.fs_close(fd)
    end)
  end)
end

---@param template any usually a `string.format` template, anything else is inspected
---@param ... any
---@return string
local function format(template, ...)
  if select('#', ...) == 0 then
    return type(template) == 'string' and template or vim.inspect(template)
  end
  local ok, msg = pcall(string.format, template, ...)
  if not ok then
    return ('could not format %s with %s'):format(vim.inspect(template), vim.inspect({ ... }))
  end
  return msg
end

---@param level SmartSplitsLogLevel
---@param template any
---@param ... any
local function write(level, template, ...)
  if not enabled(level) then
    return
  end

  local msg = format(template, ...)
  local path = M.file_path()
  if path then
    append(path, ('%s %s %s\n'):format(os.date('%F %T'), level:upper(), msg))
  end

  if echoed[msg] then
    return
  end
  echoed[msg] = true
  vim.schedule(function()
    vim.api.nvim_echo({ { PREFIX, 'Comment' }, { msg, HIGHLIGHTS[level] } }, true, {})
  end)
end

---@param template any
---@param ... any
function M.trace(template, ...)
  write('trace', template, ...)
end

---@param template any
---@param ... any
function M.debug(template, ...)
  write('debug', template, ...)
end

---@param template any
---@param ... any
function M.info(template, ...)
  write('info', template, ...)
end

---@param template any
---@param ... any
function M.warn(template, ...)
  write('warn', template, ...)
end

---@param template any
---@param ... any
function M.error(template, ...)
  write('error', template, ...)
end

---Notify the user directly, bypassing the configured log level. For things the
---user has to act on, like a config key that moved.
---@param level integer one of `vim.log.levels`
---@param template any
---@param ... any
function M.notify(level, template, ...)
  local msg = ('%s%s'):format(PREFIX, format(template, ...))
  -- `setup()` often runs before the UI is ready, where a notification would be
  -- lost or overwritten by the intro message
  vim.schedule(function()
    vim.notify(msg, level, { title = 'smart-splits.nvim' })
  end)
end

---Open the log file in a read only buffer that follows external writes.
function M.open_file()
  local path = M.file_path()
  if not path then
    M.notify(vim.log.levels.WARN, 'file logging is disabled, set `log.file` to enable it')
    return
  end

  vim.cmd.edit(path)
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].modifiable = false
  vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold' }, { buffer = buf, command = 'checktime' })
end

---Forget the resolved path and the echo dedupe state, so the next write starts
---over. Called when the config changes, and from tests.
function M.reset()
  resolved_path = nil
  resolved_path_failed = false
  echoed = {}
end

return M
