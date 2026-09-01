---@module 'busted'

local helpers = require('tests.helpers')

describe('smart-splits.health', function()
  local Health
  local original
  local reported

  ---Collect what the health check reports instead of rendering it.
  local function capture()
    reported = { start = {}, ok = {}, info = {}, warn = {}, error = {} }
    for _, level in ipairs({ 'start', 'ok', 'info', 'warn', 'error' }) do
      vim.health[level] = function(msg)
        table.insert(reported[level], msg)
      end
    end
  end

  ---@param level 'start'|'ok'|'info'|'warn'|'error'
  ---@param needle string
  ---@return boolean
  local function reported_matching(level, needle)
    for _, msg in ipairs(reported[level]) do
      if msg:find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  before_each(function()
    helpers.reset_plugin()
    Health = require('smart-splits.health')
    original = {}
    for _, level in ipairs({ 'start', 'ok', 'info', 'warn', 'error' }) do
      original[level] = vim.health[level]
    end
    capture()
  end)

  after_each(function()
    for level, fn in pairs(original) do
      vim.health[level] = fn
    end
    helpers.reset_plugin()
  end)

  it('runs with no backend configured', function()
    require('smart-splits').setup({})
    Health.check()
    assert.is_true(reported_matching('ok', 'config is valid'))
    assert.is_true(reported_matching('info', 'no backend configured'))
  end)

  it('reports the resolved backend', function()
    require('smart-splits').setup({ mux = { backend = helpers.mock_backend({ name = 'in-use' }) } })
    Health.check()
    assert.is_true(reported_matching('ok', 'in-use'))
  end)

  it('resolves when it is the first thing to ask', function()
    local Config = require('smart-splits.config')
    -- assign past setup(), so nothing has resolved yet when health runs
    Config.mux.backend = helpers.mock_backend({ name = 'not-yet-resolved' })
    Health.check()
    assert.is_true(reported_matching('ok', 'not-yet-resolved'))
    assert.is_false(reported_matching('warn', 'is smart-splits loaded'))
  end)

  it('reports a version mismatch as an error', function()
    require('smart-splits').setup({ mux = { backend = helpers.mock_backend({ protocol_version = 99 }) } })
    Health.check()
    assert.is_true(reported_matching('error', 'protocol version 99'))
  end)

  it('reports an undetected backend without treating it as an error', function()
    require('smart-splits').setup({
      mux = {
        backend = helpers.mock_backend({
          name = 'undetected',
          detect = function()
            return false
          end,
        }),
      },
    })
    Health.check()
    assert.is_true(reported_matching('info', 'detect() returned false'))
    assert.equal(0, #reported.error)
  end)

  it('runs health for a backend that did not win', function()
    local loser = helpers.mock_backend({
      name = 'loser',
      detect = function()
        return false
      end,
      health = function()
        vim.health.info('loser health ran')
      end,
    })
    local winner = helpers.mock_backend({ name = 'winner' })
    require('smart-splits').setup({ mux = { backend = { loser, winner } } })
    Health.check()
    assert.is_true(reported_matching('info', 'loser health ran'))
  end)

  it('emits the section header for the backend', function()
    require('smart-splits').setup({
      mux = {
        backend = helpers.mock_backend({
          name = 'has-health',
          health = function()
            vim.health.ok('all good')
          end,
        }),
      },
    })
    Health.check()
    assert.is_true(reported_matching('start', "backend 'has-health'"))
  end)

  it('survives a backend whose health throws', function()
    require('smart-splits').setup({
      mux = {
        backend = helpers.mock_backend({
          health = function()
            error('health exploded')
          end,
        }),
      },
    })
    Health.check()
    assert.is_true(reported_matching('error', 'health() errored'))
  end)

  it('surfaces config problems as warnings', function()
    require('smart-splits').setup({ default_amount = 5 })
    Health.check()
    assert.is_true(reported_matching('warn', 'resize.amount'))
  end)

  it('reports the supported protocol versions', function()
    require('smart-splits').setup({})
    Health.check()
    assert.is_true(reported_matching('info', 'supported protocol versions'))
  end)
end)
