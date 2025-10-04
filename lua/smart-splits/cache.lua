---@class Cache
---@field private _value any
---@field private _timestamp number
---@field private _ttl number
local Cache = {}
Cache.__index = Cache

---Create a new TTL cache
---@param ttl number|nil Time-to-live in seconds (default: 0.1)
---@return Cache
function Cache.new(ttl)
  local self = setmetatable({}, Cache)
  self._value = nil
  self._timestamp = 0
  self._ttl = ttl or 0.1
  return self
end

---Get the cached value if it's still valid
---@return any|nil value The cached value, or nil if expired or not set
function Cache:get()
  if not self._value then
    return nil
  end

  local now = vim.loop.hrtime() / 1e9
  if (now - self._timestamp) >= self._ttl then
    self._value = nil
    return nil
  end

  return self._value
end

---Set a value in the cache
---@param value any The value to cache
function Cache:set(value)
  self._value = value
  self._timestamp = vim.loop.hrtime() / 1e9
end

---Invalidate the cache
function Cache:invalidate()
  self._value = nil
  self._timestamp = 0
end

---Get or compute a value
---@param compute_fn fun():any Function to compute the value if cache is invalid
---@return any value The cached or computed value
function Cache:get_or_set(compute_fn)
  local cached = self:get()
  if cached ~= nil then
    return cached
  end

  local value = compute_fn()
  if value ~= nil then
    self:set(value)
  end
  return value
end

return Cache
