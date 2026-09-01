---@module 'busted'

local helpers = require('tests.helpers')

describe('smart-splits.config', function()
  local Config

  before_each(function()
    helpers.reset_plugin()
    Config = require('smart-splits.config')
  end)

  after_each(function()
    helpers.reset_plugin()
  end)

  describe('defaults', function()
    it('applies without calling setup', function()
      assert.equal(3, Config.resize.amount)
      assert.equal('wrap', Config.move.at_edge)
      assert.is_false(Config.move.same_row)
      assert.is_false(Config.swap.move_cursor)
      assert.is_nil(Config.mux.backend)
      assert.is_true(Config.mux.warn_if_unusable)
      assert.equal('info', Config.log.level)
      assert.is_true(Config.log.file)
    end)

    it('reports no issues for an empty config', function()
      Config.setup({})
      assert.same({}, Config.issues())
    end)
  end)

  describe('merging', function()
    it('overrides a nested value without dropping its siblings', function()
      Config.setup({ resize = { amount = 10 } })
      assert.equal(10, Config.resize.amount)
      assert.same({ 'BufEnter', 'WinEnter' }, Config.resize.ignored_events)
    end)

    it('replaces a list rather than merging it index by index', function()
      Config.setup({ ignored_buftypes = { 'terminal' } })
      assert.same({ 'terminal' }, Config.ignored_buftypes)
    end)

    it('starts from the defaults on every call rather than accumulating', function()
      Config.setup({ resize = { amount = 10 } })
      Config.setup({ move = { same_row = true } })
      assert.equal(3, Config.resize.amount)
      assert.is_true(Config.move.same_row)
    end)
  end)

  describe('ignores', function()
    it('falls back to the top level lists', function()
      Config.setup({ ignored_buftypes = { 'terminal' }, ignored_filetypes = { 'help' } })
      local buftypes, filetypes = Config.ignores('resize')
      assert.same({ 'terminal' }, buftypes)
      assert.same({ 'help' }, filetypes)
    end)

    it('replaces the top level list with a bare feature list', function()
      Config.setup({
        ignored_filetypes = { 'NvimTree' },
        resize = { ignored_filetypes = { 'Trouble' } },
      })
      local _, resize_filetypes = Config.ignores('resize')
      local _, move_filetypes = Config.ignores('move')
      assert.same({ 'Trouble' }, resize_filetypes)
      assert.same({ 'NvimTree' }, move_filetypes)
    end)

    it('unions with the top level list when inherit is set', function()
      Config.setup({
        ignored_filetypes = { 'NvimTree', 'neo-tree' },
        resize = { ignored_filetypes = { inherit = true, 'Trouble' } },
      })
      local _, filetypes = Config.ignores('resize')
      assert.same({ 'NvimTree', 'neo-tree', 'Trouble' }, filetypes)
    end)

    it('inherits the effective top level list, not the built in defaults', function()
      Config.setup({
        ignored_filetypes = { 'only-this' },
        move = { ignored_filetypes = { inherit = true, 'and-this' } },
      })
      local _, filetypes = Config.ignores('move')
      assert.same({ 'only-this', 'and-this' }, filetypes)
    end)

    it('overrides buftypes and filetypes independently', function()
      Config.setup({
        ignored_buftypes = { 'nofile' },
        ignored_filetypes = { 'NvimTree' },
        move = { ignored_buftypes = { 'terminal' } },
      })
      local buftypes, filetypes = Config.ignores('move')
      assert.same({ 'terminal' }, buftypes)
      assert.same({ 'NvimTree' }, filetypes)
    end)

    it('does not leak the inherit flag into the resolved list', function()
      Config.setup({ resize = { ignored_filetypes = { inherit = true, 'Trouble' } } })
      local _, filetypes = Config.ignores('resize')
      for _, value in ipairs(filetypes) do
        assert.equal('string', type(value))
      end
      assert.is_nil(filetypes.inherit)
    end)
  end)

  describe('v2 keys', function()
    it('reports a renamed key with its new home', function()
      Config.setup({ default_amount = 5 })
      assert.equal(1, #Config.issues())
      assert.truthy(Config.issues()[1]:find('resize.amount', 1, true))
    end)

    it('reports every renamed key it finds', function()
      Config.setup({
        default_amount = 5,
        multiplexer_integration = 'tmux',
        at_edge = 'split',
        log_level = 'debug',
      })
      assert.equal(4, #Config.issues())
    end)

    it('reports a removed key with a reason', function()
      Config.setup({ float_win_behavior = 'mux' })
      assert.equal(1, #Config.issues())
      assert.truthy(Config.issues()[1]:find('previous window', 1, true))
    end)

    it('reports backend specific keys as moved to the backend plugin', function()
      Config.setup({ kitty_password = 'hunter2', wezterm_cli_path = '/usr/bin/wezterm' })
      assert.equal(2, #Config.issues())
    end)

    it('does not apply a renamed key', function()
      Config.setup({ default_amount = 5 })
      assert.equal(3, Config.resize.amount)
    end)
  end)

  describe('unknown keys', function()
    it('reports an unknown key inside a section', function()
      Config.setup({ move = { at_egde = 'stop' } })
      assert.equal(1, #Config.issues())
      assert.truthy(Config.issues()[1]:find('move.at_egde', 1, true))
    end)

    it('reports an unknown top level key', function()
      Config.setup({ totally_made_up = true })
      assert.equal(1, #Config.issues())
    end)

    it('points at the docs', function()
      Config.setup({ totally_made_up = true })
      assert.truthy(Config.issues()[1]:find('smart-splits-configuration', 1, true))
    end)

    it('accepts every documented key without complaint', function()
      Config.setup({
        ignored_buftypes = {},
        ignored_filetypes = {},
        resize = { amount = 1, ignored_events = {}, ignored_buftypes = {}, ignored_filetypes = {} },
        move = { at_edge = 'stop', same_row = true, ignored_buftypes = {}, ignored_filetypes = {} },
        swap = { move_cursor = true },
        mux = { backend = nil, warn_if_unusable = false },
        log = { level = 'debug', file = false },
      })
      assert.same({}, Config.issues())
    end)
  end)

  describe('value validation', function()
    it('rejects an invalid at_edge and keeps the default', function()
      Config.setup({ move = { at_edge = 'wrapp' } })
      assert.equal(1, #Config.issues())
      assert.equal('wrap', Config.move.at_edge)
    end)

    it('accepts a function for at_edge', function()
      Config.setup({ move = { at_edge = function() end } })
      assert.same({}, Config.issues())
      assert.equal('function', type(Config.move.at_edge))
    end)

    it('rejects a non numeric resize amount', function()
      Config.setup({ resize = { amount = '3' } })
      assert.equal(1, #Config.issues())
      assert.equal(3, Config.resize.amount)
    end)

    it('rejects an unknown log level', function()
      Config.setup({ log = { level = 'verbose' } })
      assert.equal(1, #Config.issues())
      assert.equal('info', Config.log.level)
    end)

    it('rejects a log file that is neither boolean nor string', function()
      Config.setup({ log = { file = 42 } })
      assert.equal(1, #Config.issues())
      assert.is_true(Config.log.file)
    end)

    it('rejects a backend of the wrong type', function()
      Config.setup({ mux = { backend = 42 } })
      assert.equal(1, #Config.issues())
      assert.is_nil(Config.mux.backend)
    end)
  end)
end)
