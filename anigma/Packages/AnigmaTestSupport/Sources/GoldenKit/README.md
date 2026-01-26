# GoldenKit

GoldenKit provides deterministic byte-level comparison and verification for Anigma capsules.

## Features
- **Golden Comparison**: Compare Data, String, or JSON against canonical "golden" files.
- **Normalization**: Automatic masking of non-deterministic fields like UUIDs and Timestamps.
- **Diff Export**: Automatic export of actual vs. expected artifacts on failure to `test-results/diffs/`.
- **XCTest Integration**: Convenient `XCTAssertGolden` and `XCTAssertGoldenString` extensions.

## Usage

### Adding a Golden Test
1. Create a golden file in your capsule's tests: `Packages/MyCapsule/Tests/Golden/my_output.golden`.
2. In your test file:
```swift
import GoldenKit

func testMyOutput() {
    let output = try myCapsule.process(input)
    XCTAssertGolden(output, "MyCapsule/my_output.golden")
}
```

### Updating Golden Files
If the change in output is intentional, you can update the golden file by replacing the one in `Packages/MyCapsule/Tests/Golden/` with the `.actual` file from `test-results/diffs/`.

### Normalization
Use `XCTAssertGoldenString(actual, path, normalize: true)` to automatically mask UUIDs and timestamps.
For JSON, use `XCTAssertGoldenJSON(actual, path)` to ensure sorted keys and pretty-printing.

## Infrastructure
Golden files are stored under `Packages/*/Tests/Golden/` and are versioned alongside the code.
Failure artifacts are exported to the project root's `test-results/diffs/` directory, which is collected by CI on failure.
