local M = {}

M.directory = string.format('%s/smart_splits_nvim', vim.fn.stdpath('log'))
M.filepath = string.format('%s/log.txt', M.directory)

function M.init()
  -- ensure directory exists
  if vim.fn.isdirectory(M.directory) == 0 then
    vim.fn.mkdir(M.directory, 'p')
  end

  return M
end

function M.append(line)
  local file = io.open(M.filepath, 'a')
  if file == nil then
    vim.api.nvim_err_writeln(string.format('Failed to write file %s', M.filepath))
    return
  end
  local line_ending = vim.fn.has('win32') == 1 and '\r\n' or '\n'
  file:write(string.format('%s%s', line, line_ending))
  file:close()
end

function M.read()
  if vim.fn.filereadable(M.filepath) == 0 then
    return {}
  end

  local lines = {}
  for line in io.lines(M.filepath) do
    table.insert(lines, line)
  end

  return lines
end

return M
