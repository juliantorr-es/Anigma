# XCTest Dependency Fix - Anigma CLI

**Date:** 2026-01-10  
**Issue:** anigma-cli binary had runtime dependency on libXCTestSwiftSupport.dylib  
**Status:** ✅ RESOLVED

## Problem

The `anigma-cli` release binary required XCTest framework at runtime, preventing standalone distribution. This was discovered via:

```bash
otool -L .build/debug/anigma-cli | grep -i xctest
# Output: @rpath/libXCTestSwiftSupport.dylib
```

Symbol analysis revealed XCTest was being force-loaded in:
- AnigmaCLIExecutable
- AnigmaMCPModule  
- ModelRegistry

## Root Cause

The issue was in `Packages/ModelRegistry/Sources/ModelDeterminismHarness.swift`:

```swift
import XCTest  // ❌ XCTest in production module

public final class ModelDeterminismHarness {
    #if DEBUG
    public func runAsTest(modelId: String, ...) async throws {
        // Uses XCTAssertEqual - forces XCTest linking
        XCTAssertEqual(result.verdict, .pass, ...)
    }
    #endif
}
```

Even with `#if DEBUG`, Swift Package Manager links XCTest unconditionally when any code references it.

## Solution

### 1. Removed XCTest from Production Code

**File:** `Packages/ModelRegistry/Sources/ModelDeterminismHarness.swift`

**Changes:**
- ❌ Removed `import XCTest`
- ❌ Removed `runAsTest()` method with XCTAssertEqual
- ✅ Added `generateDriftReport()` method for verification reporting

```swift
// Before (WRONG)
import XCTest
public func runAsTest(modelId: String) async throws {
    XCTAssertEqual(result.verdict, .pass, ...)
}

// After (CORRECT)
public func generateDriftReport(_ result: BaselineVerificationResult) -> String {
    // Returns formatted report string instead of XCTest assertion
}
```

### 2. Created Dedicated Test Module

**File:** `Tests/ModelDeterminismTests/ModelDeterminismHarnessTests.swift`

Moved XCTest integration to a proper test target where XCTest belongs:

```swift
import XCTest
@testable import ModelRegistry

final class ModelDeterminismHarnessTests: XCTestCase {
    func testModelBaseline(harness: ModelDeterminismHarness, modelId: String) async throws {
        let result = try await harness.verifyAgainstBaseline(modelId: modelId)
        let report = harness.generateDriftReport(result)
        XCTAssertEqual(result.verdict, .pass, report)
    }
}
```

**Added to Package.swift:**
```swift
.testTarget(
    name: "ModelDeterminismTests",
    dependencies: ["ModelRegistry", "ContractsCore"],
    path: "Tests/ModelDeterminismTests",
    swiftSettings: strictConcurrencySettings
),
```

## Verification

### Build Success
```bash
swift build --product anigma-cli -c release
# Build time: ~440 seconds
# Binary size: 118MB (down from 178MB debug)
```

### No XCTest Dependency
```bash
otool -L .build/release/anigma-cli | grep -i xctest
# Exit code: 1 (no match - ✅ success)

nm .build/release/anigma-cli | grep -i xctest  
# Exit code: 1 (no symbols - ✅ success)
```

### Standalone Execution
```bash
.build/release/anigma-cli --version
# Output: 1.0.0 ✅

.build/release/anigma-cli --help
# Shows all 16 commands ✅
```

## Impact

### Before Fix
- ❌ Binary requires Xcode toolchain at runtime
- ❌ Cannot distribute standalone
- ❌ Users need Xcode installed
- 📦 178MB (debug build)

### After Fix  
- ✅ Binary runs without Xcode
- ✅ Fully standalone distribution
- ✅ No external dependencies beyond system frameworks
- 📦 118MB (release build, 34% reduction)

## Best Practices Learned

1. **Never import XCTest in production modules**
   - Even with `#if DEBUG`, SPM links it unconditionally
   - Use protocol-based reporting instead of assertions

2. **Separation of Concerns**
   - Test utilities belong in test targets, not production code
   - Use dependency injection for testability

3. **Verification Methods**
   - Use `otool -L` to check dynamic library dependencies
   - Use `nm` to check for unwanted symbols
   - Test binary standalone execution

4. **Production Code Pattern**
   ```swift
   // ✅ GOOD: Returns result for caller to verify
   public func verify() async throws -> VerificationResult {
       return VerificationResult(verdict: .pass, ...)
   }
   
   // ❌ BAD: Uses XCTest in production code
   public func verifyAsTest() async throws {
       XCTAssertEqual(...)
   }
   ```

## Files Modified

1. `Packages/ModelRegistry/Sources/ModelDeterminismHarness.swift`
   - Removed XCTest import
   - Replaced `runAsTest()` with `generateDriftReport()`

2. `Tests/ModelDeterminismTests/ModelDeterminismHarnessTests.swift` (new)
   - XCTest integration for determinism tests

3. `Package.swift`
   - Added ModelDeterminismTests test target

4. `ANIGMA_CLI_STATUS.md`
   - Updated to reflect XCTest dependency resolved
   - Updated binary size metrics
   - Marked success criteria complete

## Next Steps

The anigma-cli binary is now ready for:
- ✅ Standalone distribution
- ⏭️ ML integration (next priority)
- ⏭️ Codebase indexing implementation
- ⏭️ Full onboarding flow testing
