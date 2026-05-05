# MediaBackendRegistry Fix - tb-2026-05-04

## Starting MediaBackendRegistry Error Count
6 errors identified in the blocker list

## Error Classification

1. **Invalid redeclaration / duplicate symbol (1 error)**
   - `capabilityProbe` declared as both:
     - `private let capabilityProbe: HardwareCapabilityProbe` (property)
     - `public func capabilityProbe() -> HardwareCapabilityProbe` (method)
   - Compiler cannot distinguish between property access and method call

2. **Actor-isolated calls from nonisolated context (5 errors)**
   - Synchronous methods on `HardwareCapabilityProbe` actor called from `MediaBackendRegistry` actor without `await`
   - Methods affected:
     - `supportsMetalPerformanceShaders()` (line 54)
     - `supportsAudioDSP()` (line 63)
     - `supportsHardwareDecode(for:)` (lines 97, 106, 114)
   - Both `MediaBackendRegistry` and `HardwareCapabilityProbe` are actors, requiring `await` for cross-actor calls

## Root Cause

Newly introduced in Phase 2: `HardwareCapabilityProbe` actor added as dependency to `MediaBackendRegistry` actor. When `MediaBackendRegistry` methods call `HardwareCapabilityProbe` methods, Actor isolation requires the calling context to be async and use `await` to cross actor boundaries. Additionally, the property name `capabilityProbe` conflicted with the accessor method `capabilityProbe()`.

## Files Modified

- `anigma/Sources/MediaCore/Services/MediaBackendRegistry.swift`

## Actor-Isolation Strategy

- Made `selectExecutor` and `selectVideoDecoder` methods `async throws` (previously `throws`)
- Added `await` to all 5 `capabilityProbe` method calls
- Respected actor boundaries between `MediaBackendRegistry` and `HardwareCapabilityProbe`
- No `@preconcurrency` or `nonisolated` used; isolation preserved

## Redeclaration Strategy

- Renamed private property from `capabilityProbe` to `_capabilityProbe`
- Renamed public method from `capabilityProbe()` to `getCapabilityProbe()`
- No duplicate symbols in same target
- Method not used externally (verified by grep), so API change is safe

## Changes Made

```swift
// Property renaming
- private let capabilityProbe: HardwareCapabilityProbe
+ private let _capabilityProbe: HardwareCapabilityProbe

// Method renaming
- public func capabilityProbe() -> HardwareCapabilityProbe { return capabilityProbe }
+ public func getCapabilityProbe() -> HardwareCapabilityProbe { return _capabilityProbe }

// Method signature changes
- public func selectExecutor<C: MediaContract>(for contract: C) throws -> ExecutorKind
+ public func selectExecutor<C: MediaContract>(for contract: C) async throws -> ExecutorKind

- private func selectVideoDecoder(codec: String) throws -> ExecutorKind
+ private func selectVideoDecoder(codec: String) async throws -> ExecutorKind

// Actor-isolated call fixes (5 locations)
- if capabilityProbe.supportsMetalPerformanceShaders()
+ if await _capabilityProbe.supportsMetalPerformanceShaders()

- if capabilityProbe.supportsAudioDSP()
+ if await _capabilityProbe.supportsAudioDSP()

- if capabilityProbe.supportsHardwareDecode(for: codecLower)
+ if await _capabilityProbe.supportsHardwareDecode(for: codecLower)
```

## Package Graph Changes
None. No new dependencies, no new targets, no @_exported imports.

## Validation Results

Pending: HarmoniaV2Memory errors are blocking build before MediaBackendRegistry compilation.
The HarmoniaV2Memory errors (missing MemoryStore/MemoryStoreError types, store naming conflict) are a separate blocker and are NOT addressed in this fix per task constraints.

## Caller Compatibility

- `MediaSubstrateOrchestrator.execute(contract:)` already uses `try await backendRegistry.selectExecutor(for:)`
- Caller is compatible with signature change from `throws` to `async throws`
- Both `MediaSubstrateOrchestrator` and `MediaBackendRegistry` are actors in the same module (MediaCore)

## Remaining Blockers

1. HarmoniaV2Memory - ~15 errors (separate blocker, not touched per doctine)

## Architecture Statement

- **Registry implementation remains in owning layer**: MediaBackendRegistry continues to own its HardwareCapabilityProbe dependency in MediaCore (Tier 2)
- **Actor isolation respected**: Cross-actor calls now use `await`; no isolation bypassed with `nonisolated` or `@preconcurrency`
- **No dependency cycles introduced**: Only local changes within MediaCore target
- **No @_exported imports introduced**: No new exported imports added
- **Tier validation remains clean**: Changes stay within Tier 2 (MediaCore); no Tier 1 or Tier 3 dependencies modified
- **Backend semantics unchanged**: Only compile-safe isolation fixes; selectExecutor logic unchanged
- **Package graph unchanged**: No new targets, no dependency changes
