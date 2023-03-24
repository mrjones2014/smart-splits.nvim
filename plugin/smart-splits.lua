local cmds = require('smart-splits.commands')

vim.tbl_map(function(cmd)
  vim.api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
end, cmds)
