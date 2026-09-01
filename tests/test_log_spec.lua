---@module 'busted'

local helpers = require('tests.helpers')

describe('smart-splits.log', function()
  local Log
  local Config
  local tmpdir

  ---Wait for the async file write to land.
  ---@param path string
  ---@return string[]
  local function read(path)
    vim.wait(1000, function()
      return vim.fn.filereadable(path) == 1 and vim.fn.getfsize(path) > 0
    end, 10)
    if vim.fn.filereadable(path) == 0 then
      return {}
    end
    return vim.fn.readfile(path)
  end

  before_each(function()
    helpers.reset_plugin()
    Log = require('smart-splits.log')
    Config = require('smart-splits.config')
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, 'p')
  end)

  after_each(function()
    vim.fn.delete(tmpdir, 'rf')
    helpers.reset_plugin()
  end)

  describe('levels', function()
    it('exposes them from least to most severe', function()
      assert.same({ 'trace', 'debug', 'info', 'warn', 'error' }, Log.levels)
    end)

    it('writes a message at or above the configured level', function()
      local path = vim.fs.joinpath(tmpdir, 'at-level.log')
      Config.setup({ log = { level = 'warn', file = path } })
      Log.error('an error')
      assert.equal(1, #read(path))
    end)

    it('drops a message below the configured level', function()
      local path = vim.fs.joinpath(tmpdir, 'below-level.log')
      Config.setup({ log = { level = 'warn', file = path } })
      Log.debug('a debug message')
      vim.wait(100)
      assert.equal(0, vim.fn.filereadable(path))
    end)

    it('keeps warnings when the level is warn', function()
      local path = vim.fs.joinpath(tmpdir, 'warn.log')
      Config.setup({ log = { level = 'warn', file = path } })
      Log.warn('a warning')
      assert.equal(1, #read(path))
    end)

    it('drops warnings when the level is error', function()
      local path = vim.fs.joinpath(tmpdir, 'error-only.log')
      Config.setup({ log = { level = 'error', file = path } })
      Log.warn('a warning')
      vim.wait(100)
      assert.equal(0, vim.fn.filereadable(path))
    end)

    it('keeps everything at trace', function()
      local path = vim.fs.joinpath(tmpdir, 'trace.log')
      Config.setup({ log = { level = 'trace', file = path } })
      Log.trace('a trace message')
      assert.equal(1, #read(path))
    end)
  end)

  describe('file', function()
    it('writes nothing when disabled', function()
      Config.setup({ log = { level = 'trace', file = false } })
      Log.error('an error')
      vim.wait(100)
      local default = vim.fs.joinpath(vim.fn.stdpath('log') --[[@as string]], 'smart-splits.log')
      local before = vim.fn.getfsize(default)
      Log.error('another error')
      vim.wait(100)
      assert.equal(before, vim.fn.getfsize(default))
    end)

    it('writes to a configured path', function()
      local path = vim.fs.joinpath(tmpdir, 'custom.log')
      Config.setup({ log = { level = 'info', file = path } })
      Log.info('hello')
      local lines = read(path)
      assert.equal(1, #lines)
      assert.truthy(lines[1]:find('hello', 1, true))
    end)

    it('creates the parent directory', function()
      local path = vim.fs.joinpath(tmpdir, 'nested', 'deeper', 'custom.log')
      Config.setup({ log = { level = 'info', file = path } })
      Log.info('hello')
      assert.equal(1, #read(path))
    end)

    it('records the level in each line', function()
      local path = vim.fs.joinpath(tmpdir, 'levels.log')
      Config.setup({ log = { level = 'trace', file = path } })
      Log.warn('careful')
      assert.truthy(read(path)[1]:find('WARN', 1, true))
    end)
  end)

  describe('formatting', function()
    it('applies format arguments', function()
      local path = vim.fs.joinpath(tmpdir, 'format.log')
      Config.setup({ log = { level = 'info', file = path } })
      Log.info('moved %s by %d', 'left', 3)
      assert.truthy(read(path)[1]:find('moved left by 3', 1, true))
    end)

    it('does not raise on a bad format string', function()
      local path = vim.fs.joinpath(tmpdir, 'bad-format.log')
      Config.setup({ log = { level = 'info', file = path } })
      Log.info('%d', 'not a number')
      assert.truthy(read(path)[1]:find('could not format', 1, true))
    end)

    it('leaves a message with no arguments alone', function()
      local path = vim.fs.joinpath(tmpdir, 'no-args.log')
      Config.setup({ log = { level = 'info', file = path } })
      Log.info('100% done')
      assert.truthy(read(path)[1]:find('100% done', 1, true))
    end)
  end)
end)
