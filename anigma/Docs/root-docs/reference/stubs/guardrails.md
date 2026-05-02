# Stub Guardrails & Policy

**Status**: ✅ Active  
**Enforcement**: Automated tests + CI workflow (`stub-guardrails.yml`)  
**Last Updated**: 2026-02-13

---

## Overview

**Problem**: Silent stubs make code appear to work when it doesn't. They return placeholder values (nil, [], 0, false) without warning, creating "haunted" code paths that fail invisibly.

**Solution**: All stubs must be **loud** (announce themselves before returning) and **tracked** (have inventory markers for prioritization).

---

## Rules

### ✅ Rule 1: All Stubs Must Be Loud

**Before returning a placeholder value, print a warning:**

```swift
public func stubFunction() -> Int {
    // STUB: Feature X not implemented
    print("⚠️  STUB INVOKED: ModuleName.stubFunction()")
    print("   Feature X is not yet implemented - returning placeholder value")
    return 0  // Placeholder
}
```

**Why?** Loud stubs make issues immediately visible in logs, preventing silent failures and confusion.

### ✅ Rule 2: All Loud Stubs Should Be Tracked

**Add a STUB_TRACK marker above the stub:**

```swift
// STUB_TRACK: feature-x-impl – Feature X implementation stub
public func stubFunction() -> Int {
    print("⚠️  STUB INVOKED: ModuleName.stubFunction()")
    print("   Feature X is not yet implemented - returning placeholder value")
    return 0  // Placeholder
}
```

**Why?** STUB_TRACK markers enable:
- Automated inventory and reporting
- Prioritization of implementation work
- Visibility into stub debt across the codebase

### ✅ Rule 3: Keep Markers Machine-Searchable

Use the exact prefix `// STUB_TRACK:` and keep the marker immediately above the loud stub (within 5 lines), because guardrail scanning relies on that proximity.

```swift
// STUB_TRACK: feature-x-impl – Feature X implementation stub
print("⚠️  STUB INVOKED: ModuleName.function()")
```

---

## Enforcement

### Automated Tests

**Test**: `Tests/GovernanceHarness/Tests/GovernanceTests/StubGuardrailTests.swift`

**What it checks:**
1. ❌ **Silent stubs**: Detects placeholder returns (including nil, [], 0, false/true, "", [:], Data(), UUID()) with "Placeholder"/"Stub"/"Not implemented" comments but no warning
2. ⚠️  **Untracked stubs**: Detects loud stubs without STUB_TRACK markers

**When it runs:**
- CI: On every pull request and push via `.github/workflows/stub-guardrails.yml`
- Local: `swift test --filter StubGuardrailTests`

**What happens when it fails:**
- Test fails with specific file:line locations
- Developer must fix before merge

---

## Patterns

### ❌ Bad: Silent Return

```swift
public func getConfig() -> Config? {
    return nil  // Placeholder
}
```

**Problem**: Caller receives nil without knowing it's a stub. Appears to be normal error case.

### ✅ Good: Loud Return

```swift
public func getConfig() -> Config? {
    // STUB: Config initialization not implemented
    print("⚠️  STUB INVOKED: ConfigManager.getConfig()")
    print("   Config initialization is not yet implemented - returning nil")
    return nil  // Placeholder
}
```

**Better**: Caller sees warning in logs immediately when stub is invoked.

### ✅ Best: Loud + Tracked Return

```swift
// STUB_TRACK: config-init – Config initialization stub
public func getConfig() -> Config? {
    // STUB: Config initialization not implemented
    print("⚠️  STUB INVOKED: ConfigManager.getConfig()")
    print("   Config initialization is not yet implemented - returning nil")
    return nil  // Placeholder
}
```

**Best**: Stub is loud AND tracked in inventory for prioritization.

---

## Stub Types

### 1. Silent Return (❌ Forbidden)

```swift
return nil  // Placeholder
return []   // Stub
return 0    // Not implemented
```

**Status**: ❌ Blocked by `testNoSilentStubs()`

### 2. Silent Throw (⚠️ Discouraged)

```swift
throw MyError.notImplemented("Feature X")
```

**Status**: ⚠️ Allowed but discouraged. Prefer loud throw (below).

### 3. Loud Return (✅ Required)

```swift
print("⚠️  STUB INVOKED: ModuleName.function()")
print("   Reason and context")
return placeholderValue
```

**Status**: ✅ Required for all stubs

### 4. Loud Throw (✅ Best for Errors)

```swift
print("⚠️  STUB INVOKED: ModuleName.function()")
print("   This operation is not supported")
throw MyError.notImplemented("Feature X")
```

**Status**: ✅ Preferred for operations that should fail

---

## STUB_TRACK Format

### Syntax

```
// STUB_TRACK: <id> – <description>
```

### Rules

- **id**: Kebab-case identifier (e.g., `feature-x-impl`)
- **id**: Must be unique across codebase
- **description**: Brief (1-2 sentence) description
- **separator**: Use ` – ` (space-dash-space)

### Examples

```swift
// STUB_TRACK: aws-bedrock-streaming – AWS Bedrock streaming not implemented
// STUB_TRACK: mlx-inference-batch – MLX batch inference stub
// STUB_TRACK: vector-polygon-ops – Vector capsule polygon operations
```

---

## Inventory & Reporting

### View Current Stubs

```bash
# See quick reference
cat STUB_INVENTORY_QUICK_REF.md

# See full audit
cat STUB_INVENTORY_AUDIT.md

# Run tech debt scanner
swift run harmonia-cli tech-debt

# Verify loud stubs have nearby STUB_TRACK markers
python3 - <<'PY'
import os
for dp,_,files in os.walk("anigma"):
    if any(x in dp for x in ["/Tests/","/.build/","/Docs/","/.github/"]):
        continue
    for f in files:
        if not f.endswith(".swift"): continue
        p = os.path.join(dp, f)
        lines = open(p, encoding="utf-8").read().splitlines()
        for i,l in enumerate(lines):
            if "⚠️" in l and "STUB INVOKED" in l:
                if not any("STUB_TRACK:" in lines[j] for j in range(max(0, i-5), i)):
                    print(f"{p}:{i+1}")
PY
```

### Add New Stub Entry

1. Add STUB_TRACK marker in code
2. Run tech debt audit: `swift run harmonia-cli tech-debt`
3. Review missing entries
4. Add entry to `Docs/TechDebt.md` if prioritizing

---

## FAQ

### Q: Why can't I just return nil?

**A**: Silent nils look like normal error cases. Without a warning, developers won't know the feature is unimplemented. Logs are essential for debugging production issues.

### Q: What if my stub is in a hot path?

**A**: 
1. Consider if the stub should exist at all (can you gate the feature?)
2. If needed, use `#if DEBUG` guards:
   ```swift
   #if DEBUG
   print("⚠️  STUB INVOKED: ...")
   #endif
   ```
3. Better: Replace stub with real implementation

### Q: What if I'm scaffolding a new module?

**A**: Scaffolds with placeholder implementations should:
1. Be clearly marked as templates (in `Templates/` or with `Template` in name)
2. Still include warning comments explaining they're scaffolds
3. Not be imported/used by production code

### Q: Do test stubs need warnings?

**A**: Test-only stubs (in `*Tests/` or `TestSupport/`) are exempt. The test clearly indicates they're stubs.

---

## Related Documents

- **STUB_INVENTORY_QUICK_REF.md**: Current stub inventory summary
- **STUB_INVENTORY_AUDIT.md**: Full audit report with details
- **Docs/TechDebt.md**: Tech debt tracking document (if it exists)

---

## History

- **2026-02-13**: Guardrails implemented with automated tests
- **2024**: Initial stub audit completed (9 stubs made loud)

---

## Questions?

Refer to:
- This document for policy
- `StubGuardrailTests.swift` for enforcement details
- `STUB_INVENTORY_QUICK_REF.md` for current state
