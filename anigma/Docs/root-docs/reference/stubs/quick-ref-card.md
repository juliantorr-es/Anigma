# Stub Quick Reference Card

## ❌ DON'T: Silent Stub

```swift
func getConfig() -> Config? {
    return nil  // Placeholder
}
```

**Problem**: Silent failure. No visibility in logs.

---

## ✅ DO: Loud Stub

```swift
func getConfig() -> Config? {
    // STUB: Config initialization not implemented
    print("⚠️  STUB INVOKED: ConfigManager.getConfig()")
    print("   Config initialization is not yet implemented - returning nil")
    return nil  // Placeholder
}
```

**Better**: Visible in logs immediately.

---

## ✅✅ BEST: Loud + Tracked Stub

```swift
// STUB_TRACK: config-init – Config initialization stub
func getConfig() -> Config? {
    // STUB: Config initialization not implemented
    print("⚠️  STUB INVOKED: ConfigManager.getConfig()")
    print("   Config initialization is not yet implemented - returning nil")
    return nil  // Placeholder
}
```

**Best**: Visible AND tracked for prioritization.

---

## Test Your Changes

```bash
# Run stub guardrails
./check_stubs.sh

# Or manually
cd Tests/GovernanceHarness
swift test --filter StubGuardrailTests
```

---

## More Info

- **Policy**: `STUB_GUARDRAILS.md`
- **Inventory**: `STUB_INVENTORY_QUICK_REF.md`
- **Implementation**: `STUB_GUARDRAILS_IMPLEMENTATION_SUMMARY.md`
- **Visible stub entry surfaces**: `AnigmaCoreJobsRuntimeStub.swift`, `AnigmaCoreSecurityRuntimeStub.swift`, `AnigmaCorePipelineStub.swift`, `ANECapsuleIntegrationStub.swift`
