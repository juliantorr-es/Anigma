# Stub Inventory - Quick Reference

## Summary

**Total stubs inventoried**: 23  
**Fixed (made loud)**: 18  
**Remaining identified**: 2  
**Deferred (already loud)**: 4
**Guardrails**: ✅ Automated tests active

---

## 🛡️ Guardrails Active

**Test**: `Tests/GovernanceHarness/Tests/GovernanceTests/StubGuardrailTests.swift`

**Protects against:**
1. ❌ New silent stubs (returns without warnings)
2. ⚠️  Loud stubs without STUB_TRACK markers

**Policy**: See `STUB_GUARDRAILS.md`

---

## ✅ What Was Fixed

### 15 files modified to make stubs loud (9 from initial audit + 6 new):

**Initial audit (9):**
1. **Packages/AnigmaCorporate/Connectors/BlackbaudConnector.swift** - Added loud warning before throw
2. **Packages/AnigmaCorporate/Connectors/BoxConnector.swift** - Added loud warning before throw
3. **Packages/AnigmaCorporate/Connectors/ClioConnector.swift** - Added loud warning before throw
4. **Packages/AnigmaCorporate/Connectors/DropboxConnector.swift** - Added loud warning before throw
5. **Packages/AnigmaCorporate/Connectors/QuickBooksConnector.swift** - Added loud warning before throw
6. **Sources/AnigmaMCPModule/MCPExecutionCoordinator.swift** - Added warnings to getToolMetrics() and getAllMetrics()
7. **Sources/RLMModule/ContextEnvironment.swift** - Added warning to verifyClaim()
8. **Scripts/check_marshalling_budgets.swift** - Changed ✅ to ⚠️ in output

**Guardrail enforcement (6):**
9. **Sources/AnigmaCLI/CLI/CLIConfiguration.swift:139** - Added warning to getEmbeddingModel()
10. **Sources/AnigmaCLI/CLI/CLIConfiguration.swift:145** - Added warning to getCodeLLM()
11. **Packages/AnigmaDaemonCore/.../DaemonServer+Vault.swift:176** - Added warning to resolveVaultSizeBytes()
12. **Packages/HarmoniaModule/.../ValidationSkipGovernor.swift:383** - Added warning to getRecentSkipCount()
13. **Packages/VectorCapsule/.../VectorCapsule.swift:46** - Added warning to douglasPeuckerSimplify()
14. **Packages/VectorCapsule/.../VectorCapsule.swift:50** - Added warning to pointInPolygon()
15. **Packages/VectorCapsule/.../VectorCapsule.swift:54** - Added warning to getBounds()

### Latest `silent-stub-audit` remediations (3):

16. **Packages/HarmoniaModule/Inference/MLXBackendRunner.swift:153** - Added fail-fast guard + `STUB_TRACK` for non-chat streaming requests (throws before creating stream)
17. **Packages/AnigmaCLI/Providers/CloudProviders.swift:752** - Added `STUB_TRACK` + loud warning prints for AWS Bedrock embeddings
18. **Packages/AnigmaCLI/Sources/LocalInference/MLXBackend.swift:37,50** - Added `STUB_TRACK` + loud warnings before `MLXError.notImplemented` throws

---

## ⚠️ Remaining High-Priority Items

### Requires architectural changes (cannot safely fix without refactoring):

1. **AWS Bedrock Streaming** - `Packages/AnigmaCLI/Providers/CloudProviders.swift:740`
    - Need provider capability system to prevent registration

2. **Provider capability gating (follow-up)** - `Packages/AnigmaCLI/Providers/CloudProviders.swift`
   - Streaming/embeddings now loud, but provider can still be selected despite missing capabilities

---

## 🔍 How to Find More Stubs

Search patterns for future audits:

```bash
# Silent throws
grep -r "throw.*[Nn]ot.*implemented" --include="*.swift"

# Silent nil returns  
grep -r "return nil.*[Pp]laceholder" --include="*.swift"

# Placeholder data
grep -r "placeholder.*not.*implement" --include="*.swift"

# TODOs in functions that return success-like values
grep -r "TODO.*return.*true\|return.*\[\]" --include="*.swift"
```

---

## 📋 Stub Pattern Guide

### ✅ Good: Loud Stub
```swift
public func stubFunction() -> Int {
    print("⚠️  STUB INVOKED: MyModule.stubFunction()")
    print("   Feature not implemented - returning placeholder")
    return 0
}
```

### ⚠️ Bad: Silent Return
```swift
public func stubFunction() -> Int {
    return 0  // Placeholder
}
```

### ✅ Good: Loud Stub with Throw
```swift
public func stubFunction() throws {
    print("⚠️  STUB INVOKED: MyModule.stubFunction()")
    print("   This operation is not supported")
    throw MyError.notImplemented("Feature X")
}
```

### ⚠️ Bad: Silent Throw
```swift
public func stubFunction() throws {
    throw MyError.notImplemented("Feature X")
}
```

---

## 📁 Files You Can Reference

- **STUB_INVENTORY_AUDIT.md** - Full detailed audit report
- This file - Quick reference for stub patterns and findings

---

## 🎯 Next Actions

1. Review remaining 3 high-priority stubs
2. Implement provider capability system for AWS Bedrock
3. Document MLX streaming request.kind support matrix
4. Run this audit again after major feature additions
