---Protocol conformance tests for backends. Backends can require this module
---in their own test suites to verify they implement the protocol correctly.
---
---Each test is a `{name, fn}` pair. `fn()` returns `true` on pass, or an error
---string on failure. Backends can iterate them in any test framework:
---
---```lua
---local protocol_tests = require('smart-splits.protocol_tests')
---for _, test in ipairs(protocol_tests.tests(my_backend)) do
---  it(test.name, function()
---    local result = test.fn()
---    if result ~= true then
---       error(result)
---    end
---  end)
---end
---```
---
---Or run them all at once without a framework:
---
---```lua
---local results = require('smart-splits.protocol_tests').run(my_backend)
---for _, r in ipairs(results) do
---  print(r.ok and 'PASS' or 'FAIL', r.name, r.ok == true and '' or r.ok)
---end
---```

local Backend = require('smart-splits.backend')

local DIRECTIONS = { 'left', 'right', 'up', 'down' }

local M = {}

---@class SmartSplitsProtocolTest
---@field name string
---@field fn fun():true|string returns true on pass, error message on failure

---@param backend SmartSplitsBackend
---@return SmartSplitsProtocolTest[]
function M.tests(backend)
  local tests = {}

  table.insert(tests, {
    name = 'passes structural validation',
    fn = function()
      local err = Backend.validate(backend)
      if err then
        return err
      end
      return true
    end,
  })

  table.insert(tests, {
    name = 'detect() returns a boolean',
    fn = function()
      local ok, result = pcall(backend.detect)
      if not ok then
        return ('detect() errored: %s'):format(result)
      end
      if type(result) ~= 'boolean' then
        return ('detect() returned %s, expected boolean'):format(type(result))
      end
      return true
    end,
  })

  for _, direction in ipairs(DIRECTIONS) do
    table.insert(tests, {
      name = ('move(%q, {}) returns a boolean'):format(direction),
      fn = function()
        local ok, result = pcall(backend.move, direction, {})
        if not ok then
          return ('move(%q) errored: %s'):format(direction, result)
        end
        if type(result) ~= 'boolean' then
          return ('move(%q) returned %s, expected boolean'):format(direction, type(result))
        end
        return true
      end,
    })
  end

  if backend.resize then
    for _, direction in ipairs(DIRECTIONS) do
      table.insert(tests, {
        name = ('resize(%q, {amount=1}) returns a boolean'):format(direction),
        fn = function()
          local ok, result = pcall(backend.resize, direction, { amount = 1 })
          if not ok then
            return ('resize(%q) errored: %s'):format(direction, result)
          end
          if type(result) ~= 'boolean' then
            return ('resize(%q) returned %s, expected boolean'):format(direction, type(result))
          end
          return true
        end,
      })
    end
  end

  if backend.activate then
    table.insert(tests, {
      name = 'activate() does not error',
      fn = function()
        local ok, err = pcall(backend.activate)
        if not ok then
          return ('activate() errored: %s'):format(err)
        end
        return true
      end,
    })
  end

  if backend.health then
    table.insert(tests, {
      name = 'health() does not error',
      fn = function()
        local ok, err = pcall(backend.health)
        if not ok then
          return ('health() errored: %s'):format(err)
        end
        return true
      end,
    })
  end

  return tests
end

---@class SmartSplitsProtocolTestResult
---@field name string
---@field ok true|string

---@param backend SmartSplitsBackend
---@return SmartSplitsProtocolTestResult[]
function M.run(backend)
  local results = {}
  for _, test in ipairs(M.tests(backend)) do
    local ok = test.fn()
    table.insert(results, { name = test.name, ok = ok })
  end
  return results
end

return M
