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

Add your tests to `Packages/MyNewCapsule/Tests/MyNewCapsuleTests/`. The template provides several files:
- `MyNewCapsuleTests.swift`: General unit tests and edge cases.
- `MyNewCapsuleContractTests.swift`: Validation of `CapsuleError` requirements.
- `MyNewCapsuleGoldenTests.swift`: Deterministic output verification.

### Implementing your first Golden Test

Golden tests ensure that your capsule's output remains deterministic over time. The template includes a `Golden/` directory for this purpose.

1.  **Generate your baseline**: Run your capsule with a specific input and save the output to a file in `Tests/MyNewCapsuleTests/Golden/sample.golden`.
2.  **Use GoldenKit**: In `MyNewCapsuleGoldenTests.swift`, use the `GoldenKit` placeholder or manual comparison to verify the current output against the golden file.

```swift
func testGoldenOutput() async throws {
    let input = "Anigma Golden Test"
    let result = try await capsule.process(input)
    
    // Example using GoldenKit (placeholder API):
    /*
    try await GoldenKit.assertMatches(
        result,
        named: "sample",
        in: Bundle.module
    )
    */
}
```

3.  **Updating goldens**: If you intentionally change the output format, you must update the golden files in the `Golden/` directory to reflect the new expected state.

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
