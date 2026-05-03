# Swift Driver

**Source Repository:** `swiftlang/swift-driver`
**Commit:** `302fc811f4557302aa7be961321a4ae6053be0d1`
**Key File:** `Sources/SwiftDriver/Jobs/Job.swift`
**Key Symbols:** `public struct Job` (L21)

## Job and Build Plan
In `Sources/SwiftDriver/Jobs/Job.swift` (L21), the `Job` struct encapsulates frontend invocations, linking steps, and module emissions with explicitly defined inputs and outputs. This explicitly structured graph enables precise caching.

## Anigma Doctrine Takeaways
- **Compiler-Driver Diagnostic Handling:** Anigma should prefer machine-readable or structured diagnostic outputs where available from the driver. Otherwise, Anigma must preserve raw logs as evidence with explicit parser limitations, acknowledging that stdout scraping is fundamentally brittle.
- **Build Plan Evidence:** The Swift Driver's explicit job structure maps out compiler intent. This can serve as an evidence surface to verify module boundaries.
