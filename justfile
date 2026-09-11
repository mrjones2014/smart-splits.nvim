# Run all tests
test *ARGS:
    busted {{ ARGS }}

# Check formatting
fmt-check:
    stylua --check lua tests
    yamlfmt -gitignore_excludes -dry .
    prettier --check "**/*.{json,jsonc}"
    tombi format --offline --check .
    nixfmt --check flake.nix treefmt.nix

# Format code
fmt:
    stylua lua tests
    yamlfmt -gitignore_excludes .
    prettier --write "**/*.{json,jsonc}"
    tombi format --offline .
    nixfmt flake.nix treefmt.nix

# Run selene
lint:
    selene ./lua/ ./tests/
    actionlint
    statix check

# Run LuaLS type checking
typecheck:
    #!/usr/bin/env bash
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    VIMRUNTIME="$(nvim --clean -i NONE --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quitall')" \
    lua-language-server --check=. --checklevel=Warning --check_format=pretty --configpath=.luarc.json --logpath="$tmpdir/luals"

# Run all checks
check: fmt-check lint typecheck test
