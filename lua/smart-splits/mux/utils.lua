local M = {}

function M.are_we_tmux()
  if M.are_we_gui() then
    return false
  end

  local term = vim.trim((vim.env.TERM_PROGRAM or ''):lower())
  return term == 'tmux'
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

---Initialization for mux capabilities.
---If selected mux has an `on_init` or `on_exit`,
---call `on_init` and set up autocmds to call `on_init` on `VimResume`
---and `on_exit` on `VimSuspend` and `VimLeave`.
function M.startup()
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
    vim.api.nvim_create_autocmd({ 'VimSuspend', 'VimLeave' }, {
      callback = function()
        mux.on_exit()
      end,
    })
  end
end

return M
