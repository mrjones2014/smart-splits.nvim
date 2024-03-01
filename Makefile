default: check

.PHONY: check-luacheck
check-luacheck:
	@echo "Running \`luacheck\`..."
	@luacheck lua/
	@echo ""

.PHONY: check-stylua # stylua gets run through a separate GitHub Action in CI
check-stylua:
	@if test -z "$$CI"; then echo "Running \`stylua\`..." && stylua ./lua/ && echo "No stylua errors found.\n"; fi

.PHONY: check
check: check-luacheck check-stylua

.PHONY: ensure-doc-deps
ensure-doc-deps:
	@mkdir -p vendor
	@if test ! -d ./vendor/ts-vimdoc.nvim; then git clone  git@github.com:ibhagwan/ts-vimdoc.nvim.git ./vendor/ts-vimdoc.nvim/; fi
	@if test ! -d ./vendor/nvim-treesitter; then git clone git@github.com:nvim-treesitter/nvim-treesitter.git ./vendor/nvim-treesitter/; fi

.PHONY: update-doc-deps
update-doc-deps: ensure-doc-deps
	@echo "Updating ts-vimdoc.nvim..."
	@cd ./vendor/ts-vimdoc.nvim/ && git pull && cd ..
	@echo "updating nvim-treesitter..."
	@cd ./vendor/nvim-treesitter/ && git pull && cd ..

.PHONY: gen-vimdoc
gen-vimdoc: update-doc-deps
	@echo 'Installing Treesitter parsers...'
	@nvim --headless -u ./vimdocrc.lua -c 'TSUpdateSync markdown' -c 'TSUpdateSync markdown_inline' -c 'qa'
	@echo 'Generating vimdocs...'
	@nvim --headless -u ./vimdocrc.lua -c 'luafile ./vimdoc-gen.lua' -c 'qa'
	@nvim --headless -u ./vimdocrc.lua -c 'helptags doc' -c 'qa'

