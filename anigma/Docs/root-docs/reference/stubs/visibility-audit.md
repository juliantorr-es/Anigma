# Stub Visibility Audit – Complete Reference

## Quick Access

### For Urgent Review
1. **STUB_HARDENING_SUMMARY.md** ← START HERE (5 min read)
   - Quick visual reference
   - All 9 hidden modules at a glance
   - Risk levels and status

### For Deep Dive
2. **STUB_INVENTORY_COMPLETE.md** (30 min read)
   - Full inventory with details
   - Risk assessment by module
   - Specific Package.swift line numbers
   - Recommendations & next steps

### For Quick Facts
3. **STUB_QUICK_REF_CARD.md** (existing)
   - Pattern examples: good vs bad stubs
   - Testing instructions

### For Policy
4. **STUB_GUARDRAILS.md** (existing)
   - Stub management policies
   - Documentation requirements

---

## What Was Found

### CRITICAL Discovery: 9 Module-Level Stubs
These modules have **real implementations but Package.swift only lists stub files**:

| Module | Hidden Files | Active Use | Line to Fix |
|--------|--------------|-----------|------------|
| **ContextumModule** | **48** | ✅ RLMModule, CathedralModule, AnigmaDaemonCore | **937** |
| PragmaModule | 32 | ❓ Unknown | 905 |
| DiaplasionModule | 24 | ❓ Unknown | 887 |
| ConexusModule | 18 | ❓ Unknown | 912 |
| ObservatoriumModule | 13 | 🚨 Telemetry broken | 927 |
| OutlineumModule | 11 | ❓ Unknown | 898 |
| HarmoniaMemory | 7 | 🚨 Memory broken | 880 |
| AnimationKit | 5 | 🚨 UI rendering broken | 745 |
| TranscriptumModule | 4 | ❓ Unknown | 920 |
| **TOTAL** | **162+** | | |

---

## What Was Changed

### ✅ 10 Files Hardened (No Build Impact)

**Stub Module Headers** (9 files):
- Added `⚠️ STUB_TRACK` marker comments
- Point to exact Package.swift line needing fix
- List count of hidden real files
- Explain impact to developers

**Active Code** (1 file):
- AWS Bedrock streaming: Added loud warnings BEFORE stream creation
- Print: `⚠️ STUB INVOKED: AWSBedrockProvider.streamChat()`
- Now fails early instead of mid-conversation

### ✅ Documentation Created
- `STUB_INVENTORY_COMPLETE.md` - Full audit report
- `STUB_HARDENING_SUMMARY.md` - Quick reference

### ✅ Additional visible stub surfaces
- Core runtime entry stubs now carry explicit `STUB_TRACK` banners:
  - `AnigmaCoreJobsRuntimeStub.swift`
  - `AnigmaCoreSecurityRuntimeStub.swift`
  - `AnigmaCorePipelineStub.swift`
  - `ANECapsuleIntegrationStub.swift`

---

## Danger Levels

### 🔴 CRITICAL (Block Production)
**ContextumModule** - 48 real files hidden, actively used:
- RLMModule calls it for semantic search → gets placeholder data
- CathedralModule calls it for composition → gets placeholder
- AnigmaDaemonCore calls it → produces wrong results

### 🟡 HIGH (Reduced Capability)
- **ObservatoriumModule**: Telemetry system broken (13 hidden files)
- **AnimationKit**: UI rendering broken (5 hidden files)
- **HarmoniaMemory**: Memory management broken (7 hidden files)

### 🟡 MEDIUM (Silent Stubs)
- AWS Bedrock streaming - now has loud warnings
- Other 5 modules - impact unknown

---

## How Stubs Were Hidden (Important Pattern!)

**The Problem:**
```swift
// anigma/Package.swift line 937
.target(
    name: "ContextumModule",
    path: "Sources/ContextumModule",
    sources: ["ContextumModuleStub.swift"]  // ← ONLY stub file!
)
```

**What Actually Exists:**
```
Sources/ContextumModule/
├── ContextumModuleStub.swift     ← INCLUDED (placeholder)
├── ContextumModule.swift         ← EXCLUDED (real impl!)
├── Database/                     ← EXCLUDED (48 real files)
├── Systems/                      ← EXCLUDED (search, embeddings, etc.)
└── ... 48+ more real files       ← ALL EXCLUDED
```

**Why This Is Dangerous:**
- Not visible in typical code review
- Can't see it's a stub by looking at imports
- Only visible if you know to check Package.swift
- Real code exists but is silently ignored by build

---

## Next Steps (Required to Fix)

### Priority 1: Fix Package.swift (BLOCKS REAL IMPL)
Update 9 lines:
```
Line 745:  AnimationKit
Line 880:  HarmoniaMemory
Line 887:  DiaplasionModule
Line 898:  OutlineumModule
Line 905:  PragmaModule
Line 912:  ConexusModule
Line 920:  TranscriptumModule
Line 927:  ObservatoriumModule (Telemetry)
Line 937:  ContextumModule (MOST CRITICAL)
```

**Change Pattern:**
```swift
// BEFORE:
sources: ["ModuleNameStub.swift"],

// AFTER: (Option 1 - Include all)
// Remove sources parameter entirely

// AFTER: (Option 2 - Explicit list)
sources: glob("*.swift").filter { !$0.contains("Test") }
```

### Priority 2: Add Runtime Guards
For ContextumModule (and others actively used):
```swift
public enum ContextumModule {
    public static func register(runtime: PlatformRuntime) async throws {
        #if STUB_BUILD
        preconditionFailure("""
            ContextumModule is building from stub only.
            Real implementations exist but Package.swift excludes them.
            See STUB_INVENTORY_COMPLETE.md for details.
            """)
        #endif
    }
}
```

### Priority 3: Add CI Test
Prevent regression:
```swift
// CI/Tests: Verify modules are not stub-only
XCTAssertTrue(ContextumModule.hasRealImplementation, 
    "ContextumModule.swift not included in Package.swift build")
```

---

## Files Modified

```
✅ anigma/Sources/ContextumModule/ContextumModuleStub.swift
✅ anigma/Packages/HarmoniaMemory/HarmoniaMemoryStub.swift
✅ anigma/Packages/DiaplasionModule/DiaplasionModuleStub.swift
✅ anigma/Packages/OutlineumModule/OutlineumModuleStub.swift
✅ anigma/Packages/PragmaModule/Sources/PragmaModule/PragmaModuleStub.swift
✅ anigma/Packages/ConexusModule/Sources/ConexusModule/ConexusModuleStub.swift
✅ anigma/Packages/TranscriptumModule/TranscriptumModuleStub.swift
✅ anigma/Packages/ObservatoriumModule/ObservatoriumModuleStub.swift
✅ anigma/Packages/AnimationKit/Sources/AnimationKit/AnimationKitStub.swift
✅ anigma/Packages/AnigmaCLI/Providers/CloudProviders.swift (AWS Bedrock)
```

---

## Search Keywords for Finding These Issues

To find similar hidden-implementation stubs in future:
- `sources: [.*Stub.swift"]` in Package.swift
- Real files existing in directory but excluded from build
- Module name imports but stub-like behavior observed
- Silent placeholder returns vs expected real results

---

## Related Documentation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| STUB_INVENTORY_COMPLETE.md | Full audit findings | 30 min |
| STUB_HARDENING_SUMMARY.md | Quick reference | 5 min |
| STUB_GUARDRAILS.md | Stub policies | 15 min |
| STUB_INVENTORY_AUDIT.md | Previous audit (9 stubs fixed) | 20 min |
| STUB_QUICK_REF_CARD.md | Pattern examples | 5 min |

---

## Status Summary

| Item | Status |
|------|--------|
| Critical stubs inventoried | ✅ 9 modules, 162+ files |
| Dangerous stubs marked | ✅ All have `STUB_TRACK` comments |
| AWS Bedrock hardened | ✅ Loud warnings before stream |
| Package.swift fixes needed | ⏳ 9 lines to update |
| CI regression guards needed | ⏳ Tests to add |
| Runtime preconditions needed | ⏳ Code to add |

---

**Last Updated**: 2025  
**Audit Status**: ⚠️ Complete inventory + hardening applied. Package.swift fixes required.
