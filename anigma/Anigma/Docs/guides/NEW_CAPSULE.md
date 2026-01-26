# Creating a New Capsule

This guide describes how to create a new capsule in the Anigma ecosystem using the standardized template.

## Prerequisites

- Swift 6.0+
- Access to `CapsuleCore` and `TelemetryCore` packages.

## Step 1: Generate the Capsule

Run the generation script from the root of the repository:

```bash
./scripts/generate_capsule.sh MyNewCapsule 2
```

- `MyNewCapsule`: The name of your capsule (UpperCamelCase recommended).
- `2`: The tier level (default is 2).

This will create a new package in `Packages/MyNewCapsule`.

## Step 2: Define your Public API

Open `Packages/MyNewCapsule/Sources/MyNewCapsule/MyNewCapsule.swift`. This file defines the public interface.

- Ensure all public methods are `async throws`.
- Always throw `CapsuleError` variants.
- Use the `diagnostics` object to record spans and events.

## Step 3: Implement Internal Logic

Implement your actual logic in `Packages/MyNewCapsule/Sources/MyNewCapsule/MyNewCapsuleInternal.swift`. This keeps the public API file clean and focuses on the implementation.

## Step 4: Add Native C++ (Optional)

If you need high-performance C++ code:
1. Uncomment the `NewCapsuleNative` target in `Package.swift`.
2. Implement your logic in `Sources/MyNewCapsuleNative/`.
3. Use Swift's C++ interoperability to call the native code from `MyNewCapsule.swift`.

## Step 5: Write Tests

Add your tests to `Packages/MyNewCapsule/Tests/MyNewCapsuleTests/MyNewCapsuleTests.swift`.

Standard capsules should include:
- **Contract Tests**: Verify that invalid inputs return the correct `CapsuleError`.
- **Golden Tests**: Verify deterministic outputs against a known good state.
- **Edge Case Tests**: Test empty inputs, large inputs, and malformed data.

## Step 6: Verify Governance Gates

Before submitting, ensure your capsule passes all gates:

```bash
# Run tests
swift test --package-path Packages/MyNewCapsule

# Run governance checks (if available in your environment)
./scripts/check_capsule.sh Packages/MyNewCapsule
```

## Best Practices

- **Immutability**: Prefer `let` and value types where possible.
- **Sendability**: Ensure all types passed across actor boundaries are `Sendable`.
- **Structured Logging**: Use `diagnostics.event` instead of `print`.
- **Documentation**: Use DocC comments for all public APIs.
