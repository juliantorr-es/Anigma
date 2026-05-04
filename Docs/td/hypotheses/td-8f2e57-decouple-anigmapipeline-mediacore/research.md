# td-8f2e57: Remove Media Contract/Native Leakage and Eliminate Implicit Coupling

## Baseline Commands

```bash
# From /Users/user/Developer/GitHub/Anigma_clean
cd anigma
swift package describe --type json > /tmp/anigma-package.json
cp /tmp/anigma-package.json ../.build/anigma-package.json
python3 ../tools/governance/scripts/validate_no_cycles.py ../.build/anigma-package.json
python3 ../Scripts/anigma_package_graph_audit.py alignment-matrix
python3 ../tools/governance/scripts/validate_tiers.py
python3 ../tools/governance/scripts/validate_exported_imports.py
```

## Corrected Finding

**No direct SwiftPM dependency cycle exists between AnigmaPipeline and MediaCore.**

The real problem is **media contract/native leakage and implicit coupling** through shared types in FoundationContracts.

## Issue: Before Path / Implicit Coupling

```
AnigmaPipeline → AnigmaFoundation → FoundationContracts ← MediaPipelineContracts ← MediaCore
```

This is NOT a SwiftPM cycle. The issue is:
1. **Tier 1 native leakage**: FoundationContracts/MediaSubstrate/MediaPrimitives.swift imports CoreVideo and Metal
2. **Public contract break**: MediaSurface exposes CVPixelBuffer and MTLTexture in portable contract module
3. **Duplicate protocol**: SaturationSubstrateProtocol is defined in both FoundationContracts/MediaSubstrate/MediaPrimitives.swift and MediaPipelineContracts.swift
4. **Implicit coupling**: Both AnigmaPipeline and MediaCore transitively depend on FoundationContracts for media substrate types

## Symbols Involved

| Symbol | Defined In | Used In | Problem |
|---|---|---|---|
| `MediaSurface` | FoundationContracts/MediaSubstrate/MediaPrimitives.swift:9 | AnigmaPipeline, MediaCore | **Public API exposes CVPixelBuffer/MTLTexture (CoreVideo/Metal)** |
| `MediaLane` | FoundationContracts/MediaSubstrate/MediaPrimitives.swift:5 | AnigmaPipeline, MediaCore | OK (String enum, but co-located with native-leaking code) |
| `Saturable` | FoundationContracts/MediaSubstrate/MediaPrimitives.swift:32 | MediaCore executors | OK (protocol, but in wrong module) |
| `SaturationSubstrateProtocol` | FoundationContracts/MediaSubstrate/MediaPrimitives.swift:41 AND MediaPipelineContracts.swift:6 | AnigmaPipeline, MediaCore | **DUPLICATE** |
| `MediaContract` | FoundationContracts/MediaContracts.swift:6 | MediaPipelineContracts, MediaCore | OK (no native leakage) |
| `MediaArtifactStore` | MediaPipelineContracts.swift:11 | MediaCore | OK |

## Native Leakage Evidence

```bash
# Current state - native APIs in contract modules
rg "import CoreVideo|import Metal|CVPixelBuffer|MTLTexture" \
  anigma/Packages/ContractsCore/Sources/FoundationContracts \
  anigma/Packages/ContractsCore/Sources/MediaPipelineContracts

# Expected result before fix:
anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift:2:import CoreVideo
anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift:3:import Metal
anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift:15:    case pixelBuffer(CVPixelBuffer)
anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift:16:    case texture(MTLTexture)

# Expected result after fix: NO MATCHES
```

## Approved Decision: Option A

**Make the shared media surface contract portable** by replacing native CVPixelBuffer/MTLTexture exposure with opaque surface references/tokens.

This is an **intentional public contract break** in service of doctrine compliance. The Swift language docs describe access control as the mechanism to hide implementation details across module boundaries. Exposing CVPixelBuffer and MTLTexture through a portable contract module violates "Portable by contract, native by executor."

## Implementation Shape

### Phase 1: Extract Portable Types (Contract Cleanup)

Create: `anigma/Packages/ContractsCore/Sources/MediaPipelineContracts/MediaPrimitives.swift`

```swift
import Foundation
import AnigmaPrimitives

/// Opaque surface token - does NOT expose native types
public struct SurfaceToken: Hashable, Sendable, Codable {
    public let rawValue: String
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Kind of media surface (portable, no native types)
public enum MediaSurfaceKind: String, Sendable, Codable {
    case pixelBuffer
    case texture
    case audioBuffer
    case unknown
}

/// Portable media surface contract - NO CVPixelBuffer/MTLTexture in public interface
public struct MediaSurface: Sendable, Codable, Hashable {
    public let token: SurfaceToken
    public let kind: MediaSurfaceKind
    public let width: Int
    public let height: Int
    public let byteCount: Int?
    
    public init(
        token: SurfaceToken,
        kind: MediaSurfaceKind,
        width: Int,
        height: Int,
        byteCount: Int? = nil
    ) {
        self.token = token
        self.kind = kind
        self.width = width
        self.height = height
        self.byteCount = byteCount
    }
}

/// Hardware affinity lane for media operations
public enum MediaLane: String, Sendable, Codable {
    case capture
    case decode
    case transform
    case inference
}

/// Saturable processing node
public protocol Saturable: Sendable {
    var lane: MediaLane { get }
    func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface
}

/// Substrate orchestration protocol
public protocol SaturationSubstrateProtocol: Sendable {
    func process(surface: MediaSurface, lane: MediaLane, contract: any MediaContract) async throws -> MediaSurface
}
```

Note: Reuse existing token types if available (e.g., if SurfaceToken already exists in FoundationContracts/SurfaceContracts.swift, use that instead of creating a duplicate).

### Phase 2: Native Resolution (Substrate Implementation)

Move native handle resolution to MediaCore (implementation module):
- Create internal registry: `SurfaceToken -> (CVPixelBuffer | MTLTexture)`
- This registry must NOT be exposed through MediaPipelineContracts
- Native APIs (CoreVideo, Metal, etc.) remain ONLY in MediaCore
- Adapt existing code that constructs MediaSurface instances to use the portable API

## Files Expected to Change

### Package.swift
- Ensure MediaPipelineContracts has only Tier-safe dependencies: ["AnigmaPrimitives", "ContractsCore", "FoundationContracts"] (FoundationContracts only for SurfaceToken if reused)
- Ensure AnigmaPipeline depends on MediaPipelineContracts
- Ensure MediaCore depends on MediaPipelineContracts
- Remove FoundationContracts dependency from MediaPipelineContracts if SurfaceToken can be defined independently

### New/Modified Contract Files
1. `anigma/Packages/ContractsCore/Sources/MediaPipelineContracts/MediaPrimitives.swift` (NEW - portable types only)
2. `anigma/Packages/ContractsCore/Sources/MediaPipelineContracts/MediaPipelineContracts.swift` (UPDATE - remove duplicate SaturationSubstrateProtocol, keep MediaArtifactStore)

### Deleted/Neutralized Files  
3. `anigma/Packages/ContractsCore/Sources/FoundationContracts/MediaSubstrate/MediaPrimitives.swift` (DELETE - replaced by portable version in MediaPipelineContracts)

### Import Updates (AnigmaPipeline)
4. `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/SaturationSystem.swift` (UPDATE: import MediaPipelineContracts instead of FoundationContracts for media types)
5. `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/MediaFabricComponent.swift` (UPDATE: import MediaPipelineContracts, replace MediaSurface construction)

### Import Updates (MediaCore)
6. `anigma/Sources/MediaCore/Substrate/SaturationSubstrate.swift` (UPDATE: import MediaPipelineContracts)
7. All MediaCore executors (`ImageIODecodeExecutor.swift`, `VideoToolboxDecodeExecutor.swift`, `VideoToolboxEncodeExecutor.swift`, `MetalTransformExecutor.swift`, `AudioToolboxDecodeExecutor.swift`, `AccelerateDSPExecutor.swift`, `CoreImageTransformExecutor.swift`, `CameraCaptureExecutor.swift`, `MicrophoneCaptureExecutor.swift`, `MockMediaExecutor.swift`) (UPDATE: import MediaPipelineContracts, replace MediaSurface construction)

### Import Updates (Tests)
8. `anigma/Tests/MediaCoreTests/SaturationSubstratePhase5Tests.swift`
9. `anigma/Tests/MediaCoreTests/Phase2BackendTests.swift`
10. `anigma/Tests/MediaCoreTests/MediaSubstrateOrchestratorTests.swift`

### Native Registry (Phase 2 - MediaCore)
11. `anigma/Sources/MediaCore/Substrate/SurfaceRegistry.swift` (NEW - internal registry mapping SurfaceToken to CVPixelBuffer/MTLTexture)

## Expected Source Fallout

**Call sites using `.pixelBuffer(CVPixelBuffer)` or `.texture(MTLTexture)` will break.**

At native boundaries, replace with:
```swift
// OLD (contract violation):
let surface = MediaSurface.pixelBuffer(cvPixelBuffer)

// NEW (compliant):
let token = surfaceRegistry.register(pixelBuffer: cvPixelBuffer)
let surface = MediaSurface(
    token: token,
    kind: .pixelBuffer,
    width: CVPixelBufferGetWidth(cvPixelBuffer),
    height: CVPixelBufferGetHeight(cvPixelBuffer),
    byteCount: CVPixelBufferGetByteCount(cvPixelBuffer)
)
```

## Validation Baseline (Before Fix)

| Validator | Status | Finding |
|---|---|---|
| `validate_no_cycles.py` | PASS | No SwiftPM dependency cycles detected |
| `validate_tiers.py` | FAIL | Pre-existing: SecurityEventsManager → DatabaseCore (TIER_1 → TIER_2) |
| `validate_exported_imports.py` | PASS | No @_exported violations |
| `anigma_package_graph_audit.py` | INFO | 2 informational copy-minimized claim findings (ADM-0002, ADM-0003) |
| `rgba "import CoreVideo\|import Metal\|CVPixelBuffer\|MTLTexture"` | FAIL | FoundationContracts/MediaSubstrate/MediaPrimitives.swift contains native APIs |

## Expected Validation Result (After Fix)

| Validator | Expected Status | Notes |
|---|---|---|
| `validate_no_cycles.py` | PASS | No new cycles introduced |
| `validate_tiers.py` | FAIL | Pre-existing SecurityEventsManager → DatabaseCore remains; document as unrelated |
| `validate_exported_imports.py` | PASS | No new @_exported imports |
| `anigma_package_graph_audit.py` | PASS/INFO | No new P0/P1/P2 findings |
| `rgba "import CoreVideo\|import Metal\|CVPixelBuffer\|MTLTexture"` | PASS | NO MATCHES in FoundationContracts or MediaPipelineContracts |

## Public Contract Breakage

**Intentional and approved**:
- `MediaSurface` public API change: from enum with associated values `(CVPixelBuffer | MTLTexture)` to struct with `SurfaceToken`
- `Saturable` and `SaturationSubstrateProtocol` move from FoundationContracts to MediaPipelineContracts (module change, same API)
- Duplicate `SaturationSubstrateProtocol` removed

**Justification**: Exposing platform-native CoreVideo/Metal types through portable contract modules violates Anigma doctrine "Portable by contract, native by executor." The contract must be broken to achieve tier compliance.

## Non-Goals

- Do not redesign the media substrate (native resolution logic stays in MediaCore)
- Do not change Notion/publishing code
- Do not weaken validators
- Do not add @_exported imports
- Do not create umbrella modules  
- Do not move CoreVideo, Metal, AVFoundation, VideoToolbox, AudioToolbox, AppKit, SwiftUI, or other platform-native framework types into contract modules
- Do not hide graph edges
- Do not claim all tier violations are fixed (SecurityEventsManager → DatabaseCore is pre-existing and unrelated)

## Proof Artifact Template

After implementation, create: `Docs/proofs/td-8f2e57-decouple-anigmapipeline-mediacore.md`

Required sections:
- Original task name (td-8f2e57)
- Corrected finding: no direct SwiftPM cycle existed
- Actual issue: native media leakage in FoundationContracts + implicit coupling
- Symbols moved/replaced
- Before/after dependency shape
- Native API grep results proving CoreVideo/Metal absent from contract modules
- Validator results (all)
- Pre-existing unrelated violations documented
- Public contract breakage list and justification
- Follow-up needed ( Phase 2 native registry implementation if deferred)
