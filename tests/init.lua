-- Add the plugin's lua/ directory to the runtimepath so require() works
vim.opt.rtp:append('.')

-- Disable swap files and shada for test runs
vim.o.swapfile = false
vim.o.shadafile = 'NONE'

-- Silence echo/notify during tests so intentional error paths don't pollute output
vim.api.nvim_echo = function() end ---@diagnostic disable-line: duplicate-set-field
vim.notify = function() end ---@diagnostic disable-line: duplicate-set-field

-- do not write to log file in tests
require('smart-splits.config').log.file = false
