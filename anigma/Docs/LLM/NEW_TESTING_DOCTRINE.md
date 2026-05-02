# Anigma Testing Doctrine (2025)

## 1. Core Principles
- **Swift Testing**: All new tests MUST use `@Test` and `#expect`.
- **Proof-Oriented**: Tests are not just validators; they are evidence receipts for the governance plane.
- **Hardware-Aware**: All Metal/C++ tests MUST use `MTL_SHADER_VALIDATION=1`.

## 2. Technical Stack
- **Framework**: `Swift Testing`.
- **C++ Interop**: Use `Span<T>` and `SWIFT_LIFETIME_BOUND`.
- **Metal**: Programmatic frame capture on failure.
- **Concurrency**: `async` test functions with actor-isolated device management.

## 3. Governance Gates
- **Focused Filtering**: Every `swift test` run must use `--filter`.
- **CI Enforcement**: `anigma doctor` ensures the graph is clean, `anigma proof` ensures results are recorded.
