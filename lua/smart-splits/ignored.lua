---Module for managing ignored buffer/filetype checks with caching
local M = {}

-- Hash tables for O(1) lookup of ignored buffer/file types
local ignored_buftypes = {}
local ignored_filetypes = {}

---Rebuild the ignored types caches from config
---@param config SmartSplitsConfig
function M.rebuild(config)
  ignored_buftypes = {}
  ignored_filetypes = {}
  
  for _, buftype in ipairs(config.ignored_buftypes) do
    ignored_buftypes[buftype] = true
  end
  
  for _, filetype in ipairs(config.ignored_filetypes) do
    ignored_filetypes[filetype] = true
  end
end

---Check if a buffer should be ignored based on buftype or filetype
---@param bufnr number|nil Buffer number (default: current buffer)
---@return boolean
function M.is_ignored(bufnr)
  bufnr = bufnr or 0
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  return ignored_buftypes[buftype] or ignored_filetypes[filetype]
end

return M
