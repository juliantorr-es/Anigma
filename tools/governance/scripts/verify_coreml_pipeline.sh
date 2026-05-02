#!/bin/bash
set -e

echo "Verifying Core ML Pipeline Integration..."

# Build all targets
swift build --target ContractsCore
swift build --target ModelRegistry
swift build --target ANECapsuleIntegration
swift build --target HarmoniaModule
swift build --target AnigmaDaemonCore

echo "All targets build successfully!"