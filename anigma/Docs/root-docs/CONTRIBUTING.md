# Contributing to Anigma

## Code Quality & Testing

### Governance Tests

Governance tests run automatically via git pre-push hook when you change:
- `Governance/` files
- `AuthorityImplementations.swift`
- `GovernanceHarness/`
- `Package.swift` files

**Run tests manually:**
```bash
./scripts/test-governance.sh
```

**Install git hooks:**
```bash
bash scripts/install-git-hooks.sh
```

---

## Stub Implementation Rules

When creating stub implementations for testing or minimal compilation, follow these rules to prevent module interface corruption.

### ✅ DO: Conform and Throw

Stubs should conform to protocols and throw on method calls. This keeps the type system happy without redefining domain logic.

```swift
// GOOD: Stub conforms to protocol, throws on method calls
actor GovernanceControllerStub: GovernanceProtocol {
    func canWrite(_ proposal: WriteProposal) async throws -> WriteGateDecision {
        throw StubError.notImplemented("GovernanceController stub")
    }
    
    func initialize() async {
        // No-op or minimal initialization
    }
}
```

### ❌ DON'T: Redefine Production Types

**Never define domain types in stubs that exist in production code.** This causes Swift module system confusion.

```swift
// BAD: Redefining types that exist in GovernanceCore
enum OperatingMode {  // ← This type exists in production!
    case readOnly, assistive
}

public struct WriteProposal {  // ← This type exists in production!
    let principal: String
    let operation: String
}
```

**Why this fails:**
- Swift compiler sees duplicate definitions across modules
- Module exports become empty/corrupted
- Types become invisible to importers
- Tests fail with "cannot find type" errors despite public declarations

### The Fix: Import, Don't Redefine

If a stub needs a production type:
1. **Import it** from the module that defines it
2. If you can't import it, **fix the module/product structure**
3. Never copy-paste type definitions into stubs

```swift
// GOOD: Import the real types
import GovernanceCore

actor GovernanceControllerStub: GovernanceProtocol {
    func canWrite(_ proposal: WriteProposal) async throws -> WriteGateDecision {
        // WriteProposal comes from GovernanceCore, not redefined here
        throw StubError.notImplemented("stub")
    }
}
```

---

## Historical Example: Duplicate Symbol Poisoning

**Date:** 2026-02-09  
**Issue:** Governance tests couldn't import `GovernanceController` despite public declarations

**Root cause:**
We defined `OperatingMode`, `WriteProposal`, `WriteCheckResult`, and `WriteGateDecision` in **two places**:
1. `AnigmaCoreSecurityRuntimeStub.swift` (stub versions)
2. `Governance/Governance.swift` + `GovernanceCore` (real implementations)

**Symptoms:**
- Build succeeded
- `AnigmaCoreSecurityRuntime` module exported empty interface
- `@testable import` couldn't see any governance types
- Error: "cannot find 'GovernanceController' in scope"

**Fix:**
Deleted all duplicate definitions from stub file. Kept definitions only in production modules.

**Result:**
Module interface became visible, tests passed immediately.

**Lesson:**
Stub poisoning is silent until tests try to import. The build graph won't warn you. If a stub defines real domain types, you **will** hit empty module interfaces.

---

## Rule of Thumb

**Stubs throw. They don't define.**

If you find yourself copy-pasting type definitions into a stub, stop. Either:
1. Import the type from its defining module, or
2. Fix the product/target structure so the import works

Stubs exist to satisfy the compiler for minimal builds. They are not a place to duplicate architecture.

---

## Additional Guidelines

### Module Dependencies

- **Tier 1 (Governance):** Can import Foundation only
- **Tier 2 (Runtime):** Can import Tier 1, Foundation
- **Tier 3 (Capabilities):** Can import Tier 2, Foundation

Use `@_implementationOnly import` for transitive dependencies that shouldn't leak to importers.

### Testing Strategy

- Governance tests live in isolated `Tests/GovernanceHarness/` package
- No HarmoniaModule dependency (prevents 5,700 errors from blocking security tests)
- Tests run in 4-6s (build) + 0.004s (execution)

### Before Pushing

```bash
# Run governance tests
./scripts/test-governance.sh

# Or rely on git pre-push hook (auto-installed)
git push  # Hook runs automatically if governance files changed
```

---

## Questions?

Open an issue or ask in the team channel. Don't cargo-cult stub patterns from other codebases—they likely don't have our multi-tier governance requirements.
