local DOC_FILES = {
  ['./README.md'] = './doc/smart-splits.txt',
}

for input, output in pairs(DOC_FILES) do
  require('ts-vimdoc').docgen({
    input_file = input,
    output_file = output,
    project_name = output:match('/([^/]+)%.txt$'),
  })
  print(string.format('Wrote %s from source file %s', output, input))
end
print('\n')

vim.cmd('qa')
