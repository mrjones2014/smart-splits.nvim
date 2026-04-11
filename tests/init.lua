-- Add the plugin's lua/ directory to the runtimepath so require() works
vim.opt.rtp:append('.')

-- Disable swap files and shada for test runs
vim.o.swapfile = false
vim.o.shadafile = 'NONE'
