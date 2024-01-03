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

---Check if Neovim is running in Wezterm TUI
---@return boolean
function M.are_we_wezterm()
  if M.are_we_gui() then
    return false
  end
  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  local wezterm_pane = vim.trim(vim.env.WEZTERM_PANE or '')
  return term == 'wezterm' or wezterm_pane ~= ''
end

---Check if Neovim is running in a GUI (rather than TUI)
---@return boolean
function M.are_we_gui()
  -- if running in a GUI instead of terminal TUI, disable mux
  -- because you aren't in any terminal, you're in a Neovim GUI
  local current_ui = vim.tbl_filter(function(ui)
    return ui.chan == 1
  end, vim.api.nvim_list_uis())[1]
  return current_ui ~= nil and not current_ui.stdin_tty and not current_ui.stdout_tty
end

return M
