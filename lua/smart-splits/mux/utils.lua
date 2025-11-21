local M = {}

function M.are_we_tmux()
  if M.are_we_gui() then
    return false
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'tmux'
end

function M.are_we_wezterm()
  if M.are_we_gui() then
    return false
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'wezterm'
end

function M.are_we_kitty()
  if M.are_we_gui() then
    return false
  end

  return vim.env.KITTY_WINDOW_ID ~= nil
end

--- Check if we're in WSL
---@return boolean
function M.is_WSL()
  return vim.env.WSL_DISTRO_NAME ~= nil and vim.env.WSL_DISTRO_NAME ~= ''
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

local prev_win = nil

---Return the buf ID of the previous buffer, if there is one
---@return number|nil
function M.get_previous_win()
  return prev_win
end

---Initialization for mux capabilities.
---If selected mux has an `on_init` or `on_exit`,
---call `on_init` and set up autocmds to call `on_init` on `VimResume`
---and `on_exit` on `VimSuspend` and `VimLeavePre`.
function M.startup()
  -- buffer tracking for "previous buffer"
  vim.api.nvim_create_autocmd('WinLeave', {
    callback = function()
      prev_win = tonumber(vim.api.nvim_get_current_win())
    end,
  })

  -- multiplexer startup/shutdown events
  local mux = require('smart-splits.mux').get()
  if not mux then
    return
  end
  if mux.on_init then
    mux.on_init()
    vim.api.nvim_create_autocmd('VimResume', {
      callback = function()
        mux.on_init()
      end,
    })
  end
  if mux.on_exit then
    vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeavePre' }, {
      callback = function()
        mux.on_exit()
      end,
    })
  end
  if mux.update_mux_layout_details then
    vim.api.nvim_create_autocmd({ 'VimResume', 'VimEnter', 'VimResized', 'FocusGained' }, {
      callback = function()
        mux.update_mux_layout_details()
      end,
    })
  end
end

return M
