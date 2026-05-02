# Agent workflow recipes for Swift project

# Format all Swift files
format:
    fd -e swift -x swift-format format -i {}
    swiftlint lint --fix

# Run tests for specific module
test module="":
    # Find test target and run
    fd "Tests" -t d | grep "{{module}}" | xargs -I {} sh -c 'cd {} && swift test'

# Analyze codebase
analyze:
    tokei
    cscope -R -b -q

# Verify native dependency manifest hashes
verify-deps:
    anigma/Scripts/verify_native_deps.sh

# Watch for changes and run tests
watch:
    fd -e swift | entr -r swift test

# Search for pattern
search pattern="":
    rg "{{pattern}}"
