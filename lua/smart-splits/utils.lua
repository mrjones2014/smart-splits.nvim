local M = {}

function M.tbl_find(tbl, predicate)
  for idx, value in ipairs(tbl) do
    if predicate(value) then
      return value, idx
    end
  end

  return nil
end

---Check if a window is a floating window
---@param win_id number|nil window ID to check, defaults to current window (0)
---@return boolean
function M.is_floating_window(win_id)
  win_id = win_id or 0
  local win_cfg = vim.api.nvim_win_get_config(win_id)
  return win_cfg and (win_cfg.relative ~= '' or not win_cfg.relative)
end

return M
