---@meta
---@diagnostic disable
---Type definitions for the parts of busted and luassert that this test suite
---uses. Only referenced by `.luarc.json`, never loaded at runtime. Declaring the
---globals busted injects means redeclaring `assert`, so diagnostics are off for
---the whole file.

---@param description string
---@param block fun()
function describe(description, block) end

---@param description string
---@param block fun()
function it(description, block) end

---@param block fun()
function before_each(block) end

---@param block fun()
function after_each(block) end

---@class luassert
---@overload fun(value: any, message?: string): any
assert = {}

---@param expected any
---@param actual any
---@param message? string
function assert.equal(expected, actual, message) end

---@param expected any
---@param actual any
---@param message? string
function assert.equals(expected, actual, message) end

---Deep equality.
---@param expected any
---@param actual any
---@param message? string
function assert.same(expected, actual, message) end

---@param value any
---@param message? string
function assert.is_true(value, message) end

---@param value any
---@param message? string
function assert.is_false(value, message) end

---@param value any
---@param message? string
function assert.is_nil(value, message) end

---@param value any
---@param message? string
function assert.is_not_nil(value, message) end

---@param value any
---@param message? string
function assert.truthy(value, message) end

---@param value any
---@param message? string
function assert.falsy(value, message) end
