# Concurrency Compliance Report (Tier 5/3 Capsules)

Date: 2026-01-26

## Scope
- MediaFingerprintCapsule (present)
- TextPipelineCapsule (not found in repo)
- VectorIndexCapsule (not found in repo)
- TextChunkingCapsule (not found in repo)
- PDFCapsule (not found in repo)
- LayoutEngineCapsule (not found in repo)

## Before/After Status
| Capsule | Before | After | Notes |
| --- | --- | --- | --- |
| MediaFingerprintCapsule | Direct C API calls in actor implementation; no dedicated @preconcurrency wrapper | C API access routed through `MediaFingerprintNativeBridge` with `@preconcurrency` import | No `@unchecked Sendable` usage; Sendable conformances remain explicit. |
| TextPipelineCapsule | Not present | Not present | No sources located in repo. |
| VectorIndexCapsule | Not present | Not present | No sources located in repo. |
| TextChunkingCapsule | Not present | Not present | No sources located in repo. |
| PDFCapsule | Not present | Not present | No sources located in repo. |
| LayoutEngineCapsule | Not present | Not present | No sources located in repo. |

## Notes
- `@preconcurrency` is applied to `MediaFingerprintNative` imports to keep Swift 6 strict concurrency viable around the C ABI boundary.
- No `@unchecked Sendable` annotations were required in the audited capsule sources.
