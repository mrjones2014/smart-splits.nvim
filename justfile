# Check formatting and linting
lint:
    @echo "Checking formatting with Stylua..."
    @stylua --check ./lua/ ./tests/
    @echo "Checking lints with Selene..."
    @selene ./lua/

# Format all Lua files
fmt:
    @stylua ./lua/ ./tests/

# Check type annotations with lua-language-server
types:
    #!/usr/bin/env bash
    set -euo pipefail
    # `.luarc.json` refers to $VIMRUNTIME so editors pick it up from the running
    # instance; lua-language-server has no such variable, so substitute it here
    runtime="$(nvim --headless --clean -c 'echo $VIMRUNTIME' -c 'qa' 2>&1)"
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT
    sed "s|\$VIMRUNTIME|$runtime|" .luarc.json > "$workdir/luarc.json"
    lua-language-server --check . --checklevel=Warning \
      --configpath="$workdir/luarc.json" --logpath="$workdir/log"

# Run tests
test *ARGS:
    @busted {{ ARGS }}
