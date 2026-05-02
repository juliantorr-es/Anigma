#!/bin/bash
#
# run_integration_tests.sh
# Run Core ML Pipeline Integration Tests
#

set -e

# Parse command line arguments
QUICK_MODE=false
SHOW_HELP=false

for arg in "$@"; do
    case $arg in
        --quick|-q)
            QUICK_MODE=true
            ;;
        --help|-h)
            SHOW_HELP=true
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Run Core ML Pipeline Integration Tests"
    echo ""
    echo "Options:"
    echo "  -q, --quick    Run all tests together (faster)"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Test targets included:"
    echo "  • ModelRegistryIntegrationTests - Core ML pipeline and end-to-end tests"
    echo "  • ANECapsuleIntegrationTests   - Contract validation tests"
    echo "  • AnigmaDaemonCoreTests        - ANE scheduling tests"
    echo "  • ContractsCoreTests           - Additional contract validation"
    exit 0
fi

echo "🧪 Running Core ML Pipeline Integration Tests..."
if [ "$QUICK_MODE" = true ]; then
    echo "🚀 Quick mode: Running all tests together"
fi
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Must run from repository root"
    exit 1
fi

# Build tests once
echo "📦 Building test targets..."
swift build --build-tests
echo ""

# Track overall test status
OVERALL_EXIT_CODE=0

if [ "$QUICK_MODE" = true ]; then
    # Run all integration tests together
    echo "🔬 Running all Core ML integration tests..."
    if swift test --skip-build \
        --filter "ModelRegistryIntegrationTests" \
        --filter "ANECapsuleIntegrationTests" \
        --filter "AnigmaDaemonCoreTests" \
        --filter "ContractsCoreTests" 2>/dev/null; then
        echo "✅ All integration tests passed!"
        OVERALL_EXIT_CODE=0
    else
        OVERALL_EXIT_CODE=$?
        echo "⚠️  Some tests failed (exit code: $OVERALL_EXIT_CODE)"
    fi
else
    # Run tests individually with detailed reporting
    # Run ModelRegistryIntegrationTests (includes CoreMLPipelineTests and EndToEndTests)
    echo "🔬 Running ModelRegistryIntegrationTests..."
    if swift test --skip-build --filter "ModelRegistryIntegrationTests" 2>/dev/null; then
        echo "✅ ModelRegistryIntegrationTests passed!"
    else
        TEST_EXIT_CODE=$?
        OVERALL_EXIT_CODE=$TEST_EXIT_CODE
        echo "⚠️  ModelRegistryIntegrationTests failed (exit code: $TEST_EXIT_CODE)"
    fi
    echo ""

    # Run ANECapsuleIntegrationTests (includes ContractValidationTests)
    echo "📝 Running ANECapsuleIntegrationTests..."
    if swift test --skip-build --filter "ANECapsuleIntegrationTests" 2>/dev/null; then
        echo "✅ ANECapsuleIntegrationTests passed!"
    else
        TEST_EXIT_CODE=$?
        OVERALL_EXIT_CODE=$TEST_EXIT_CODE
        echo "⚠️  ANECapsuleIntegrationTests failed (exit code: $TEST_EXIT_CODE)"
    fi
    echo ""

    # Run AnigmaDaemonCoreTests (includes ANESchedulingTests)
    echo "⚡ Running AnigmaDaemonCoreTests..."
    if swift test --skip-build --filter "AnigmaDaemonCoreTests" 2>/dev/null; then
        echo "✅ AnigmaDaemonCoreTests passed!"
    else
        TEST_EXIT_CODE=$?
        OVERALL_EXIT_CODE=$TEST_EXIT_CODE
        echo "⚠️  AnigmaDaemonCoreTests failed (exit code: $TEST_EXIT_CODE)"
    fi
    echo ""

    # Run ContractsCoreTests for additional contract validation
    echo "📋 Running ContractsCoreTests..."
    if swift test --skip-build --filter "ContractsCoreTests" 2>/dev/null; then
        echo "✅ ContractsCoreTests passed!"
    else
        TEST_EXIT_CODE=$?
        OVERALL_EXIT_CODE=$TEST_EXIT_CODE
        echo "⚠️  ContractsCoreTests failed (exit code: $TEST_EXIT_CODE)"
    fi
    echo ""
fi

# Final status
if [ $OVERALL_EXIT_CODE -eq 0 ]; then
    echo "═══════════════════════════════════════"
    echo "🎉 All integration tests passed!"
    echo "═══════════════════════════════════════"
else
    echo "═══════════════════════════════════════"
    echo "❌ Some integration tests failed"
    echo "═══════════════════════════════════════"
    exit $OVERALL_EXIT_CODE
fi