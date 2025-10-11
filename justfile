# run all checks (linting and formatting)
check:
  @echo "Checking formatting with Stylua..."
  @stylua --check ./lua/
  @echo "Checking lints with Selene..."
  @selene ./lua/
