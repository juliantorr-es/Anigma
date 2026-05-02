# Platform Architecture: Portable by Contract, Saturated by Backend

## Strategic Principle

Anigma is **portable by contract** and **saturated by backend**.

The goal is not "avoid Apple frameworks." The goal is:
- **Portable**: contracts, manifests, receipts, TimelineIR, RenderGraphIR, MediaIntentIR, governance layer
- **Saturated**: platform-specific backend executors using native frameworks

## Platform Layers

### Tier 1: Portable Anigma Semantics
```
FrameReference
AudioBufferReference  
ImageSurfaceReference
TimelineIR
RenderGraphIR
MediaIntentIR
ArtifactManifest
CopyProof / ZeroCopyProof
ContractReceipt
```

### Tier 2: Portable Authorities & Registries
```
ExecutionAuthority
MaterializationGate
MediaBackendRegistry
ArtifactAuthority
MetadataAuthority
```

### Tier 2b/3: Platform Backend Executors
```
macOS:
  VideoToolboxBackend (VideoDecodeContract / VideoEncodeContract)
  MetalBackend (GPUTransformContract)
  AudioToolboxBackend (AudioDecodeContract / AudioEncodeContract)
  CoreImageBackend (ImageTransformContract)
  VisionBackend (VisualAnalysisContract)
  CoreMLBackend (ModelExecutionContract)
  CryptoKitReceiptSigner (ReceiptSigningContract)
  AVFoundationCaptureBackend (CaptureContract)

Linux (future):
  VAAPI / GStreamer / FFmpegBackend
  VulkanBackend
  ONNXRuntimeBackend
  OpenCVBackend
  OpenSSLReceiptSigner

Windows (future):
  MediaFoundationBackend
  DirectMLBackend
  Direct3DBackend
  WinMLBackend
  WincngReceiptSigner

Portable fallback:
  FFmpegSubprocessBackend
  CPUSIMDBackend
  SoftwareRendererBackend
```

## The Critical Rule: No Platform Types in Contracts

### Bad (platform leakage)
```swift
public struct DecodeOutput: Codable, Sendable {
    public let pixelBuffer: CVPixelBuffer  // Platform type
}

public struct ImageTransformInput {
    public let ciImage: CIImage  // Platform type
}
```

### Good (portable reference)
```swift
public struct DecodeOutput: Codable, Sendable {
    public let frame: FrameReference  // Portable
    public let proof: ZeroCopyProof  // Portable
}

public struct ImageTransformInput: Codable, Sendable {
    public let image: ImageSurfaceReference  // Portable
    public let transform: ImageTransformDescriptor  // Portable
}
```

## Backend Registry Interface

Each platform backend implements a portable role:

```
VideoToolboxDecodeExecutor
  role: VideoDecodeBackend
MetalTransformExecutor
  role: GPUTransformBackend
AudioToolboxDecodeExecutor
  role: AudioDecodeBackend
VisionAnalysisExecutor
  role: VisualAnalysisBackend
CoreMLExecutor
  role: ModelExecutionBackend
CryptoKitReceiptSigner
  role: ReceiptSigningBackend
```

## Portability Budget Template

For every Apple framework integration, document:

| Field | Value |
|-------|-------|
| Framework | VideoToolbox |
| Anigma role | VideoDecodeBackend / VideoEncodeBackend |
| Tier | Tier 2b executor |
| Portable contract | MediaDecodeContract / MediaEncodeContract |
| Reference type | FrameReference |
| Portable fallback | FFmpegSubprocessBackend |
| Future Linux equivalent | VAAPI / GStreamer / FFmpeg |
| Future Windows equivalent | Media Foundation |
| Apple types exposed outside executor | **none** |

## What Becomes Harder

- Linux app
- Windows app
- Web app
- Headless cloud deployment
- Android/iOS parity
- CI on generic containers
- Developer onboarding without Apple hardware

## What Becomes Easier

- High-performance media ingest
- On-device AI
- Zero-copy video
- Local ML
- Rich macOS UI
- Hardware-aware scheduling
- Energy-efficient execution
- Pro-grade media workflows (Capture subsystem)
- Vision/Metal/CoreML integration

## Strategic Recommendation

> Build Anigma as:
> - **Anigma Core**: portable semantics, manifests, contracts, receipts, governance
> - **Anigma macOS**: sovereign reference implementation using Apple frameworks
> - **Anigma fallback**: subprocess and software backends behind the same contracts
> - **Anigma other platforms**: later, only after macOS backend proves architecture

## The Sharp Doctrine

> **Do not make Anigma cross-platform by avoiding Apple frameworks.**
> **Make Anigma cross-platform by refusing to let Apple frameworks define the contracts.**

That gives you both: native saturation now, portability later.

## Related TD Tasks

- [td-1ff57f](td-1ff57f) Governed Capture Subsystem Epic
- [td-f03a69](td-f03a69) Capture executors (macOS → FrameReference/AudioBufferReference)
- [td-ab4392](td-ab4392) Acceptance gates (enforce portable references)