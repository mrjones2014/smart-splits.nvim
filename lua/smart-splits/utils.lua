local M = {}

function M.tbl_find(tbl, predicate)
  for idx, value in ipairs(tbl) do
    if predicate(value) then
      return value, idx
    end
  end

  return nil
end

---Check for some special cases like Snacks.explorer(),
---see https://github.com/mrjones2014/smart-splits.nvim/issues/342
local function is_special_floating_window_treat_as_non_floating(win_id, win_config)
  win_id = win_id or 0
  local buf = vim.api.nvim_win_get_buf(win_id)
  local ft = vim.bo[buf].filetype
  -- the snacks explorer is just a snacks picker in disguise;
  -- it is technically a floating window, but on the same z index
  -- as the main window, so we want to treat it as a normal window
  if ft == 'snacks_picker_list' and win_config.zindex == 33 then
    return true
  end
end

---Check if a window is a floating window
---@param win_id number|nil window ID to check, defaults to current window (0)
---@return boolean
function M.is_floating_window(win_id)
  win_id = win_id or 0
  local win_cfg = vim.api.nvim_win_get_config(win_id)
  if is_special_floating_window_treat_as_non_floating(win_id, win_cfg) then
    return false
  end
  return win_cfg.relative ~= ''
end

return M
