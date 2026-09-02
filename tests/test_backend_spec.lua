---@module 'busted'

local helpers = require('tests.helpers')

describe('smart-splits.backend', function()
  local Backend
  local Config

  before_each(function()
    helpers.reset_plugin()
    Backend = require('smart-splits.backend')
    Config = require('smart-splits.config')
  end)

  after_each(function()
    helpers.reset_plugin()
  end)

  describe('spec normalization', function()
    it('resolves an inline table', function()
      local backend = helpers.mock_backend()
      Config.setup({ mux = { backend = backend } })
      assert.equal(backend, Backend.resolve())
    end)

    it('resolves a module path string', function()
      Config.setup({ mux = { backend = 'tests.fixtures.echo_backend' } })
      local resolved = Backend.resolve()
      assert.is_not_nil(resolved)
      assert.equal('echo', resolved.name)
    end)

    it('resolves a list, preferring the earlier entry', function()
      local first = helpers.mock_backend({ name = 'first' })
      local second = helpers.mock_backend({ name = 'second' })
      Config.setup({ mux = { backend = { first, second } } })
      assert.equal('first', Backend.resolve().name)
    end)

    it('resolves a function returning a single spec', function()
      local backend = helpers.mock_backend()
      Config.setup({
        mux = {
          backend = function()
            return backend
          end,
        },
      })
      assert.equal(backend, Backend.resolve())
    end)

    it('resolves a function returning a list', function()
      local backend = helpers.mock_backend({ name = 'from-function' })
      Config.setup({
        mux = {
          backend = function()
            return { backend }
          end,
        },
      })
      assert.equal('from-function', Backend.resolve().name)
    end)

    it('resolves nothing when a function errors', function()
      Config.setup({
        mux = {
          backend = function()
            error('boom')
          end,
        },
      })
      assert.is_nil(Backend.resolve())
    end)

    it('resolves nothing when no backend is configured', function()
      Config.setup({})
      assert.is_nil(Backend.resolve())
    end)
  end)

  describe('resolution timing', function()
    -- the plugin may be lazy loaded, in which case `VimEnter` has already fired
    -- by the time anything of ours runs, so `setup()` has to do this itself
    it('resolves during setup, without waiting to be asked', function()
      local detected = false
      Config.setup({
        mux = {
          backend = helpers.mock_backend({
            detect = function()
              detected = true
              return true
            end,
          }),
        },
      })
      assert.is_true(detected)
    end)

    it('calls the backend setup during setup', function()
      local called = false
      Config.setup({
        mux = {
          backend = helpers.mock_backend({
            setup = function()
              called = true
            end,
          }),
        },
      })
      assert.is_true(called)
    end)

    it('resolves on first use when setup was never called', function()
      local backend = helpers.mock_backend()
      -- reach past setup() to mimic a config assigned some other way
      Config.mux.backend = backend
      assert.is_false(Backend.move('left'))
      assert.equal(backend, Backend.resolve())
    end)
  end)

  describe('priority', function()
    it('skips backends whose detect returns false', function()
      local skipped = helpers.mock_backend({
        name = 'skipped',
        detect = function()
          return false
        end,
      })
      local wanted = helpers.mock_backend({ name = 'wanted' })
      Config.setup({ mux = { backend = { skipped, wanted } } })
      assert.equal('wanted', Backend.resolve().name)
    end)

    it('never sets up a backend that lost', function()
      local loser_setup = false
      local winner_setup = false
      local winner = helpers.mock_backend({
        name = 'winner',
        setup = function()
          winner_setup = true
        end,
      })
      local loser = helpers.mock_backend({
        name = 'loser',
        setup = function()
          loser_setup = true
        end,
      })
      Config.setup({ mux = { backend = { winner, loser } } })
      Backend.resolve()
      assert.is_true(winner_setup)
      assert.is_false(loser_setup)
    end)

    it('calls setup exactly once across repeated resolves', function()
      local count = 0
      local backend = helpers.mock_backend({
        setup = function()
          count = count + 1
        end,
      })
      Config.setup({ mux = { backend = backend } })
      Backend.resolve()
      Backend.resolve()
      Backend.resolve()
      assert.equal(1, count)
    end)

    it('keeps working when setup errors', function()
      local backend = helpers.mock_backend({
        setup = function()
          error('bad setup')
        end,
      })
      Config.setup({ mux = { backend = backend } })
      assert.equal(backend, Backend.resolve())
    end)

    it('does not re-resolve after the first attempt', function()
      local detects = 0
      local backend = helpers.mock_backend({
        detect = function()
          detects = detects + 1
          return true
        end,
      })
      Config.setup({ mux = { backend = backend } })
      Backend.resolve()
      Backend.resolve()
      assert.equal(1, detects)
    end)
  end)

  describe('validation', function()
    local function rejects(overrides)
      Config.setup({ mux = { backend = helpers.mock_backend(overrides) } })
      assert.is_nil(Backend.resolve())
    end

    it('rejects a missing name', function()
      rejects({ name = false })
    end)

    it('rejects a missing protocol_version', function()
      rejects({ protocol_version = false })
    end)

    it('rejects a missing detect', function()
      rejects({ detect = false })
    end)

    it('rejects a missing move', function()
      rejects({ move = false })
    end)

    it('rejects an unsupported protocol version', function()
      rejects({ protocol_version = 2 })
    end)

    it('rejects move that is not a function', function()
      rejects({ move = 'not a function' })
    end)

    it('rejects an optional field of the wrong type', function()
      rejects({ health = 'not a function' })
    end)

    it('rejects a module path that cannot be required', function()
      Config.setup({ mux = { backend = 'smart-splits-backend-does-not-exist' } })
      assert.is_nil(Backend.resolve())
    end)

    it('falls through to the next candidate after an invalid one', function()
      local invalid = helpers.mock_backend({ name = 'invalid', protocol_version = 2 })
      local valid = helpers.mock_backend({ name = 'valid' })
      Config.setup({ mux = { backend = { invalid, valid } } })
      assert.equal('valid', Backend.resolve().name)
    end)

    it('rejects a backend whose detect errors', function()
      rejects({
        detect = function()
          error('detect blew up')
        end,
      })
    end)
  end)

  describe('report', function()
    it('records an entry per candidate', function()
      local invalid = helpers.mock_backend({ name = 'invalid', protocol_version = 99 })
      local undetected = helpers.mock_backend({
        name = 'undetected',
        detect = function()
          return false
        end,
      })
      local used = helpers.mock_backend({ name = 'used' })
      Config.setup({ mux = { backend = { invalid, undetected, used } } })
      Backend.resolve()

      local report = Backend.report()
      assert.equal(3, #report)
      assert.equal('invalid', report[1].status)
      assert.equal('skipped', report[2].status)
      assert.equal('resolved', report[3].status)
      assert.equal('used', report[3].spec)
    end)

    it('keeps the validated backend on skipped entries so health can reach it', function()
      local undetected = helpers.mock_backend({
        name = 'undetected',
        detect = function()
          return false
        end,
      })
      Config.setup({ mux = { backend = undetected } })
      Backend.resolve()
      assert.equal(undetected, Backend.report()[1].backend)
    end)

    it('records nothing for candidates after the resolved one', function()
      Config.setup({
        mux = { backend = { helpers.mock_backend({ name = 'a' }), helpers.mock_backend({ name = 'b' }) } },
      })
      Backend.resolve()
      assert.equal(1, #Backend.report())
    end)
  end)

  describe('delegation', function()
    it('returns false with no backend', function()
      Config.setup({})
      assert.is_false(Backend.move('left'))
      assert.is_false(Backend.resize('left', { amount = 3 }))
      assert.is_false(Backend.split('left'))
    end)

    it('passes the direction and options through', function()
      local backend, calls = helpers.mock_backend()
      Config.setup({ mux = { backend = backend } })
      Backend.move('up', { wrap = true })
      Backend.resize('down', { amount = 7 })
      Backend.split('right')

      assert.same({ 'detect', 'move', 'resize', 'split' }, helpers.ops(calls))
      assert.same({ 'move', 'up', { wrap = true } }, calls[2])
      assert.same({ 'resize', 'down', { amount = 7 } }, calls[3])
      assert.same({ 'split', 'right', {} }, calls[4])
    end)

    it('substitutes an empty table when options are omitted', function()
      local backend, calls = helpers.mock_backend()
      Config.setup({ mux = { backend = backend } })
      Backend.move('up')
      Backend.resize('down')
      Backend.split('right')

      assert.same({ 'move', 'up', {} }, calls[2])
      assert.same({ 'resize', 'down', {} }, calls[3])
      assert.same({ 'split', 'right', {} }, calls[4])
    end)

    it('reports handled when the backend returns true', function()
      Config.setup({
        mux = {
          backend = helpers.mock_backend({
            move = function()
              return true
            end,
          }),
        },
      })
      assert.is_true(Backend.move('left'))
    end)

    it('treats a missing return as not handled', function()
      Config.setup({
        mux = {
          backend = helpers.mock_backend({
            move = function() end,
          }),
        },
      })
      assert.is_false(Backend.move('left'))
    end)

    it('treats a truthy non-boolean return as not handled', function()
      for _, value in ipairs({ 0, 'yes', {} }) do
        helpers.reset_plugin()
        Config.setup({
          mux = {
            backend = helpers.mock_backend({
              move = function()
                return value
              end,
            }),
          },
        })
        assert.is_false(Backend.move('left'))
      end
    end)

    it('returns false for an operation the backend does not implement', function()
      Config.setup({ mux = { backend = helpers.mock_backend({ resize = false, split = false }) } })
      assert.is_false(Backend.resize('left', 3))
      assert.is_false(Backend.split('left'))
      assert.is_false(Backend.move('left'))
    end)

    it('survives a backend that throws', function()
      Config.setup({
        mux = {
          backend = helpers.mock_backend({
            move = function()
              error('move blew up')
            end,
          }),
        },
      })
      assert.is_false(Backend.move('left'))
      assert.is_false(Backend.move('left'))
    end)
  end)

  describe('reset', function()
    it('lets a later resolve pick a different backend', function()
      Config.setup({ mux = { backend = helpers.mock_backend({ name = 'first' }) } })
      assert.equal('first', Backend.resolve().name)

      Config.setup({ mux = { backend = helpers.mock_backend({ name = 'second' }) } })
      assert.equal('second', Backend.resolve().name)
    end)

    it('clears the report', function()
      Config.setup({ mux = { backend = helpers.mock_backend() } })
      Backend.resolve()
      Backend.reset()
      assert.equal(0, #Backend.report())
    end)
  end)

  describe('protocol version', function()
    it('exposes the current version through the plugin entry point', function()
      assert.equal(3, require('smart-splits').PROTOCOL_VERSION)
    end)

    it('supports the current version', function()
      assert.is_true(vim.tbl_contains(Backend.SUPPORTED_VERSIONS, Backend.PROTOCOL_VERSION))
    end)
  end)
end)
