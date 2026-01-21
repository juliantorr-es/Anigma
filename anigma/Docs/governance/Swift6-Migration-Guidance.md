# Swift 6 Migration: SE-0337 and Swift.org Guidance Compliance

## SE-0337 Incremental Migration Framework

This section documents how our Swift 6 migration strategy aligns with SE-0337 ("Incremental migration to concurrency checking") and Swift.org migration guidance.

### @preconcurrency Usage Rules (SE-0337 Compliance)

**Purpose**: `@preconcurrency` is a migration bridge for external dependencies only, not a general-purpose diagnostic silencer.

**Allowed Usage**:
```swift
// ✅ ALLOWED: External dependency import with concurrency issues
@preconcurrency import SomeLegacyLibrary

// ❌ PROHIBITED: Silencing our own code
@preconcurrency func myFunction() { ... }
@preconcurrency class MyClass { ... }
```

**Migration Path**:
1. Mark external imports with `@preconcurrency` when they cause diagnostics
2. Document each usage with issue tracker reference to dependency
3. Remove `@preconcurrency` when dependency updates
4. CI enforces import-only usage with automated checks

### Swift.org Migration Strategy Alignment

**Swift.org Guidance**: "Enable complete checking as warnings in Swift 5 language mode via `-strict-concurrency` and then fully via Swift 6 mode."

**Our Implementation**:
```bash
# Swift 5 compatibility (warnings)
swift build -Xswiftc -strict-concurrency=complete

# Swift 6 mode (errors)
SWIFT_STRICT_CONCURRENCY=complete swift build

# Xcode project equivalent
SWIFT_STRICT_CONCURRENCY=complete xcodebuild
```

**Key Principles from Swift.org**:
1. **Incremental Adoption**: Start with warnings, move to errors
2. **Module-Scoped Migration**: Convert modules one at a time
3. **Surface Issues Gradually**: Avoid explosion of simultaneous diagnostics

### Compiler Settings Documentation

**Swift.org Documented Settings**:
- `-Xswiftc -strict-concurrency=complete`: Command-line flag
- `SWIFT_STRICT_CONCURRENCY=complete`: Environment variable (Xcode equivalent)
- Xcode: "Strict Concurrency Checking = Complete"

**Our Enforcement**:
```bash
# Both methods validated to ensure consistency
swift build -Xswiftc -strict-concurrency=complete
SWIFT_STRICT_CONCURRENCY=complete swift build
```

### Data Race Prevention (Swift Compiler Diagnostics)

**Swift 6 Prohibitions** (explicitly documented in compiler diagnostics):
- Non-isolated mutable global variables
- Non-isolated mutable static variables  
- Unsafe data sharing across isolation domains

**Our Enforcement**:
```bash
# Detect mutable globals
rg "^[[:space:]]*var[[:space:]]+[A-Za-z_]" Sources/ --type swift

# Detect non-isolated static vars
rg "static[[:space:]]+var" Sources/ --type swift -B2 -A2
```

### Migration Success Criteria

Based on Swift.org migration docs:

1. **Zero Concurrency Diagnostics**: No warnings/errors under strict checking
2. **Sendable Compliance**: All cross-boundary types implement Sendable
3. **Proper Actor Isolation**: Mutable state properly isolated
4. **Test Coverage**: Tests pass under same strict settings

### Real-World Migration Experience

**Common Issues** (Swift.org migration experience):
- "Hundreds or thousands of diagnostics" when enabling complete checking
- Legacy dependencies with concurrency issues
- Global state that becomes illegal under strict checking

**Our Mitigation Strategies**:
- Incremental module-by-module migration
- SE-0337 @preconcurrency bridges for dependencies
- Automated detection of prohibited patterns
- CI enforcement preventing regression

### References

- [Swift.org: Migrating Your App to Swift 6](https://www.swift.org/migration/)
- [SE-0337: Incremental migration to concurrency checking](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-preconcurrency.md)
- [Swift Compiler Diagnostics: Strict Concurrency](https://github.com/apple/swift/blob/main/docs/StrictConcurrency.rst)

---

**Implementation Status**: All enforcement scripts align with Swift.org guidance and SE-0337 framework.