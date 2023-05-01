local M = {}

function M.tbl_find(tbl, predicate)
  for idx, value in ipairs(tbl) do
    if predicate(value) then
      return value, idx
    end
  end

  return nil
end

local base64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function M.base64_encode(str)
  local result = {}
  local length = #str
  local i = 1

  while i <= length do
    local char1 = string.byte(str, i)
    local char2, char3

    if i + 1 <= length then
      char2 = string.byte(str, i + 1)
    end

    if i + 2 <= length then
      char3 = string.byte(str, i + 2)
    end

    local enc1 = bit.rshift(char1, 2)
    local enc2 = bit.lshift(bit.band(char1, 3), 4) + bit.rshift(bit.band(char2 or 0, 240), 4)
    local enc3 = bit.lshift(bit.band(char2 or 0, 15), 2) + bit.rshift(bit.band(char3 or 0, 192), 6)
    local enc4 = bit.band(char3 or 0, 63)

    result[#result + 1] = string.sub(base64_chars, enc1 + 1, enc1 + 1)
    result[#result + 1] = string.sub(base64_chars, enc2 + 1, enc2 + 1)

    if char2 then
      result[#result + 1] = string.sub(base64_chars, enc3 + 1, enc3 + 1)
    else
      result[#result + 1] = '='
    end

    if char3 then
      result[#result + 1] = string.sub(base64_chars, enc4 + 1, enc4 + 1)
    else
      result[#result + 1] = '='
    end

    i = i + 3
  end

  return table.concat(result)
end

return M
