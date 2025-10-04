---@class Cache<T>
---@field private _value T|nil
---@field private _timestamp number
---@field private _ttl number
---@field private _compute_fn fun():T|nil
local Cache = {}
Cache.__index = Cache

---Create a new TTL cache
---@generic T
---@param compute_fn fun():T|nil Function to compute the value when cache is invalid
---@param ttl number|nil Time-to-live in milliseconds (default: 100)
---@return Cache<T>
function Cache.new(compute_fn, ttl)
  local self = setmetatable({}, Cache)
  self._value = nil
  self._timestamp = 0
  self._ttl = ttl or 100
  self._compute_fn = compute_fn
  return self
end

---Get the cached value, computing it if necessary
---@generic T
---@return T|nil value The cached or computed value
function Cache:get()
  if self._value ~= nil then
    local now = vim.loop.hrtime() / 1e6 -- Convert to milliseconds
    if (now - self._timestamp) < self._ttl then
      return self._value
    end
  end

  -- Cache is invalid, compute new value
  local value = self._compute_fn()
  if value ~= nil then
    self._value = value
    self._timestamp = vim.loop.hrtime() / 1e6
  end
  return value
end

---Invalidate the cache
function Cache:invalidate()
  self._value = nil
  self._timestamp = 0
end

return Cache
