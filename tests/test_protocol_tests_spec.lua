---@module 'busted'

local helpers = require('tests.helpers')

describe('smart-splits.protocol_tests', function()
  local ProtocolTests

  before_each(function()
    helpers.reset_plugin()
    ProtocolTests = require('smart-splits.protocol_tests')
  end)

  after_each(function()
    helpers.reset_plugin()
  end)

  describe('tests()', function()
    it('returns a list of test cases', function()
      local backend = helpers.mock_backend()
      local tests = ProtocolTests.tests(backend)
      assert.is_true(#tests > 0)
      for _, test in ipairs(tests) do
        assert.equal('string', type(test.name))
        assert.equal('function', type(test.fn))
      end
    end)

    it('passes a valid backend', function()
      local backend = helpers.mock_backend()
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        assert.equal(true, test.fn(), test.name)
      end
    end)

    it('passes the echo backend fixture', function()
      local echo = require('tests.fixtures.echo_backend')
      for _, test in ipairs(ProtocolTests.tests(echo)) do
        assert.equal(true, test.fn(), test.name)
      end
    end)

    it('fails structural validation for a missing required field', function()
      local backend = helpers.mock_backend({ name = false })
      local results = ProtocolTests.run(backend)
      assert.equal('passes structural validation', results[1].name)
      assert.is_true(results[1].ok ~= true)
    end)

    it('fails when detect returns a non-boolean', function()
      local backend = helpers.mock_backend({
        detect = function()
          return 'yes'
        end,
      })
      local results = ProtocolTests.run(backend)
      local found = false
      for _, r in ipairs(results) do
        if r.name == 'detect() returns a boolean' then
          assert.is_true(r.ok ~= true)
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('fails when detect throws', function()
      local backend = helpers.mock_backend({
        detect = function()
          error('detect blew up')
        end,
      })
      local results = ProtocolTests.run(backend)
      local found = false
      for _, r in ipairs(results) do
        if r.name == 'detect() returns a boolean' then
          assert.is_true(r.ok ~= true)
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('fails when move returns a non-boolean', function()
      local backend = helpers.mock_backend({
        move = function()
          return 42
        end,
      })
      local results = ProtocolTests.run(backend)
      local move_failures = 0
      for _, r in ipairs(results) do
        if r.name:match('^move%(') and r.ok ~= true then
          move_failures = move_failures + 1
        end
      end
      assert.equal(4, move_failures)
    end)

    it('fails when move throws', function()
      local backend = helpers.mock_backend({
        move = function()
          error('move blew up')
        end,
      })
      local results = ProtocolTests.run(backend)
      local move_failures = 0
      for _, r in ipairs(results) do
        if r.name:match('^move%(') and r.ok ~= true then
          move_failures = move_failures + 1
        end
      end
      assert.equal(4, move_failures)
    end)

    it('skips resize tests when resize is absent', function()
      local backend = helpers.mock_backend({ resize = false })
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        assert.is_false(test.name:match('^resize%(') ~= nil, 'should not have resize tests')
      end
    end)

    it('includes resize tests when resize is present', function()
      local backend = helpers.mock_backend()
      local resize_tests = 0
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        if test.name:match('^resize%(') then
          resize_tests = resize_tests + 1
        end
      end
      assert.equal(4, resize_tests)
    end)

    it('includes activate test when activate is present', function()
      local backend = helpers.mock_backend({
        activate = function() end,
      })
      local found = false
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        if test.name == 'activate() does not error' then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('omits activate test when activate is absent', function()
      local backend = helpers.mock_backend({ activate = false })
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        assert.is_true(test.name ~= 'activate() does not error')
      end
    end)

    it('includes health test when health is present', function()
      local backend = helpers.mock_backend({
        health = function() end,
      })
      local found = false
      for _, test in ipairs(ProtocolTests.tests(backend)) do
        if test.name == 'health() does not error' then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('fails when activate throws', function()
      local backend = helpers.mock_backend({
        activate = function()
          error('activate blew up')
        end,
      })
      local results = ProtocolTests.run(backend)
      local found = false
      for _, r in ipairs(results) do
        if r.name == 'activate() does not error' then
          assert.is_true(r.ok ~= true)
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('fails when health throws', function()
      local backend = helpers.mock_backend({
        health = function()
          error('health blew up')
        end,
      })
      local results = ProtocolTests.run(backend)
      local found = false
      for _, r in ipairs(results) do
        if r.name == 'health() does not error' then
          assert.is_true(r.ok ~= true)
          found = true
        end
      end
      assert.is_true(found)
    end)
  end)

  describe('run()', function()
    it('returns results for every test', function()
      local backend = helpers.mock_backend()
      local results = ProtocolTests.run(backend)
      local tests = ProtocolTests.tests(backend)
      assert.equal(#tests, #results)
      for _, r in ipairs(results) do
        assert.equal('string', type(r.name))
        assert.equal(true, r.ok, r.name)
      end
    end)

    it('reports both passes and failures', function()
      local backend = helpers.mock_backend({
        move = function()
          return 'not a boolean'
        end,
      })
      local results = ProtocolTests.run(backend)
      local passes = 0
      local failures = 0
      for _, r in ipairs(results) do
        if r.ok == true then
          passes = passes + 1
        else
          failures = failures + 1
        end
      end
      assert.is_true(passes > 0)
      assert.is_true(failures > 0)
    end)
  end)
end)
