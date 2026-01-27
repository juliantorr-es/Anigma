# VizAggregationCapsule

Template for creating new Anigma capsules that are Phase 0 compliant.

## Overview

This capsule template provides a starting point for building high-performance, secure, and observable components for the Anigma ecosystem.

## Compliance Features

- **Swift 6 Strict Concurrency**: All code is `@Sendable` and thread-safe.
- **Contract-Based Error Handling**: Uses `CapsuleError` for all public-facing failures.
- **Observability**: Integrated with `TelemetryCore` for distributed tracing and diagnostics.
- **Phase 0 Gates**: Passes all automated governance checks.

## Getting Started

1. Use the generator script to create your capsule:
   ```bash
   ./scripts/generate_capsule.sh MyAwesomeCapsule
   ```
2. Implement your logic in `Sources/MyAwesomeCapsule/MyAwesomeCapsuleInternal.swift`.
3. Add tests in `Tests/MyAwesomeCapsuleTests/MyAwesomeCapsuleTests.swift`.
4. Run tests:
   ```bash
   swift test
   ```

## Structure

- `Sources/VizAggregationCapsule/`: Public API and implementation.
- `Sources/VizAggregationCapsuleNative/`: (Optional) C++ bridge for performance-critical logic.
- `Tests/VizAggregationCapsuleTests/`: Unit, Contract, and Golden tests.
- `MANIFEST.toml`: Metadata and governance settings.
- `DEPS.toml`: Dependency tracking.
