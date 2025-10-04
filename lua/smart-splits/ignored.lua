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

---Check if current buffer should be ignored based on buftype or filetype
---@return boolean
function M.is_ignored()
  return ignored_buftypes[vim.bo.buftype] or ignored_filetypes[vim.bo.filetype]
end

return M
