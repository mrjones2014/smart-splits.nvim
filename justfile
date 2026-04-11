# Check formatting and linting
lint:
    @echo "Checking formatting with Stylua..."
    @stylua --check ./lua/
    @echo "Checking lints with Selene..."
    @selene ./lua/

# Run tests
test *ARGS:
    @busted {{ ARGS }}
