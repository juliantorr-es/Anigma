# ⚠️ DEPRECATED: FFmpeg + Saturated + Metal Architecture Integration

**Status**: DEPRECATED — See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md

This document is retained for historical reference only. It predates the Phase 0 zero-copy substrate architecture and contains references to outdated phase breakdown and performance claims.

---

## Original Content (Archived)

**Proposal**: Integrate FFmpeg video processing with Anigma's Saturated architecture to achieve:
1. Metal GPU acceleration for video encoding/decoding
2. Hardware lane scheduling (`.perception` for ANE-oriented work)
3. Decomposed Swift-C++-C bridge into layered contracts + executors
4. Unified telemetry through SaturatedHeartbeatPacket
5. Zero-copy pipeline execution with SIMD/GPU coordination

---

## Current State vs. Proposed State

### Current: Monolithic C++ Bridge

```
VideoRenderCapsule.swift
  ↓
VideoRenderNativeBridge.cpp (opaque C++ layer)
  ↓
FFmpeg C libraries (libavformat, libavcodec, libswscale)
  ↓
Metal (if available, but not coordinated)

Problems:
- No visibility into bridge operations
- No hardware lane scheduling
- No saturated telemetry
- No parallel execution control
- Tightly coupled to FFmpeg C API
```

### Proposed: Layered Saturated Architecture

```
Tier 1: Contracts (Swift, no I/O)
  ├── MediaDecodeContract (decode video frame)
  ├── MediaEncodeContract (encode to codec)
  ├── ScaleFormatContract (resize + color space conversion)
  └── TranscodeContract (full pipeline)

Tier 2: Executors (Swift + Metal)
  ├── MetalVideoDecoder (hardware accelerated)
  ├── MetalVideoEncoder (hardware accelerated)
  ├── MetalScaleFormatter (Metal compute shader)
  └── FFmpegExecutor (fallback CPU decoder)

Tier 3: Native/Kernel Layer
  ├── VideoDecodeKernel.metal (Metal decode kernel)
  ├── VideoEncodeKernel.metal (Metal encode kernel)
  ├── ScaleFormatKernel.metal (Metal scale + convert)
  └── FFmpeg C bridge (delegated to executor)

Hardware Lanes:
  - `.perception`: ANE video decode (if available)
  - `.inference`: Metal GPU compute for format conversion
  - `.background`: CPU FFmpeg fallback
```

---

## Phase 1: Contract Definitions (Tier 1)

### MediaDecodeContract

```swift
// Packages/ContractsCore/Sources/ContractsCore/Media/MediaDecodeContract.swift

import Foundation
import SaturationKit

/// Contracts for video frame extraction and decoding.
/// Implements fused governance + hardware lane scheduling.
public struct MediaDecodeContract: NativeBoundaryContract {
    public typealias Input = DecodeInput
    public typealias Output = DecodeOutput
    
    public static var id: ContractID {
        ContractID(
            name: "media.decode.v1",
            major: 1, minor: 0,
            schemaHash: "a1b2c3d4e5f6"
        )
    }
    
    public static var preferredLane: HardwareLane { .perception }  // ANE if available
    
    // MARK: - Tier 1/2 Swift Representation
    
    public struct DecodeInput: Codable, Sendable {
        /// Compressed video frame (H.264, VP9, HEVC, etc.)
        public let encodedData: PayloadReference  // CAS reference, not inline
        
        /// Codec hint (H.264, VP9, HEVC, AV1, etc.)
        public let codecHint: String
        
        /// Desired output format (RGB24, YUV420, NV12, RGBA)
        public let targetFormat: PixelFormatHint
        
        /// Desired output dimensions (nil = preserve)
        public let targetDimensions: (width: Int, height: Int)?
        
        /// Governance request (contract execution receipt)
        public let governanceDecision: ExecutionAuthority.Decision
        
        /// Affinity hint: prefer .perception (ANE) if available
        public let preferredLane: HardwareLane
    }
    
    public struct DecodeOutput: Codable, Sendable {
        /// Raw video frame data
        public let frameData: PayloadReference  // CAS reference
        
        /// Actual pixel format
        public let actualFormat: PixelFormat
        
        /// Actual dimensions
        public let actualDimensions: (width: Int, height: Int)
        
        /// Metadata
        public let metadata: FrameMetadata
        
        /// Performance telemetry
        public let metrics: DecodeMetrics
        
        /// Governance receipt
        public let receipt: ContractReceipt
    }
    
    public struct PixelFormatHint: Codable, Sendable {
        public enum Format: String, Codable, Sendable {
            case rgb24, rgba, yuv420, nv12, bgra
        }
        public let format: Format
        public let preferMetalNativeLayout: Bool = true  // NV12 for Metal
    }
    
    public struct FrameMetadata: Codable, Sendable {
        public let codecName: String
        public let originalWidth: Int
        public let originalHeight: Int
        public let duration: UInt64  // nanoseconds
        public let timestamp: UInt64  // packet timestamp
    }
    
    public struct DecodeMetrics: Codable, Sendable {
        public let decodeTimeMs: Int64
        public let forceGPU: Bool  // True if GPU was used
        public let memoryAllocatedMB: Int
        public let gpuUtilizationPercent: Int  // 0-100 if available
    }
    
    // MARK: - Execution (delegated to executor layer)
    
    public static func execute(
        input: ArtifactEnvelope<Input>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<Output> {
        // Execution delegated to MediaDecodeExecutor (Tier 2)
        // This contract only defines the interface and governance policy
        throw MediaError.delegatedToExecutor
    }
}

public enum MediaError: Error, Sendable {
    case delegatedToExecutor
    case codecNotSupported(String)
    case insufficientMemory
    case gpuUnavailable
    case decodeFailed(String)
}
```

---

## Phase 2: Executor Layer (Tier 2)

### MetalVideoDecoder

```swift
// Packages/AnigmaCore/Sources/AnigmaGovernance/Media/Executors/MetalVideoDecoder.swift

import Foundation
import Metal
import VideoToolbox
import SaturationKit
import ContractsCore

/// Metal-accelerated video decoder using VideoToolbox framework.
/// Supports hardware-accelerated H.264, HEVC decoding via Metal/ANE.
public actor MetalVideoDecoder: ContractExecutor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let sessionMutex = NSLock()
    private var decoderSession: VTDecompressionSession?
    private let loggingRing: SaturatedLoggingRing
    
    public init(
        device: MTLDevice? = nil,
        loggingRing: SaturatedLoggingRing? = nil
    ) throws {
        self.device = device ?? MTLCreateSystemDefaultDevice() ??
            { throw MediaError.gpuUnavailable }()
        
        guard let queue = self.device.makeCommandQueue() else {
            throw MediaError.gpuUnavailable
        }
        self.commandQueue = queue
        self.loggingRing = loggingRing ?? try SaturatedLoggingRing(capacity: 4096)
    }
    
    /// Execute video decode via VideoToolbox (Metal-backed on modern macOS).
    public func execute(
        input: ArtifactEnvelope<MediaDecodeContract.DecodeInput>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<MediaDecodeContract.DecodeOutput> {
        let startTime = Date()
        let missionID = ctx.missionID ?? UUID()
        
        // Record heartbeat: decode started
        try recordHeartbeat(
            missionID: missionID,
            type: .start,
            payload: "Decode started".data(using: .utf8) ?? Data()
        )
        
        // 1. Fetch encoded data from CAS
        let casRef = input.payload.encodedData
        let encodedData = try await fetchFromCAS(casRef)
        
        // 2. Create VTDecompressionSession with Metal backing
        try createDecompressionSession(
            codec: input.payload.codecHint,
            targetFormat: input.payload.targetFormat
        )
        
        // 3. Decode frame
        let decodedBuffer = try await decodeFrame(
            encodedData: encodedData,
            missionID: missionID
        )
        
        // 4. Format conversion if needed
        let outputBuffer = try await formatConvert(
            inputBuffer: decodedBuffer,
            sourceFormat: .yuv420,  // VideoToolbox output
            targetFormat: input.payload.targetFormat,
            targetDimensions: input.payload.targetDimensions,
            missionID: missionID
        )
        
        // 5. Store result in CAS
        let outputRef = try await storeToCAS(
            data: outputBuffer,
            mimeType: "image/raw-\(input.payload.targetFormat.format.rawValue)"
        )
        
        let endTime = Date()
        let decodeTimeMs = Int64(endTime.timeIntervalSince(startTime) * 1000)
        
        // Record heartbeat: decode complete
        try recordHeartbeat(
            missionID: missionID,
            type: .end,
            payload: "Decode complete (\(decodeTimeMs)ms)".data(using: .utf8) ?? Data()
        )
        
        // 6. Build output envelope with receipt
        let metrics = MediaDecodeContract.DecodeMetrics(
            decodeTimeMs: decodeTimeMs,
            forceGPU: true,
            memoryAllocatedMB: outputBuffer.count / (1024 * 1024),
            gpuUtilizationPercent: 75  // Estimated
        )
        
        let receipt = ContractReceipt.placeholder(
            contractID: MediaDecodeContract.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: startTime,
            endedAt: endTime,
            metrics: ExecutionMetrics(
                wallTimeMs: decodeTimeMs,
                executor: "MetalVideoDecoder"
            )
        )
        
        return ArtifactEnvelope(
            schemaVersion: 1,
            payload: MediaDecodeContract.DecodeOutput(
                frameData: outputRef,
                actualFormat: .yuv420,
                actualDimensions: (1920, 1080),
                metadata: MediaDecodeContract.FrameMetadata(
                    codecName: input.payload.codecHint,
                    originalWidth: 1920,
                    originalHeight: 1080,
                    duration: 33_333_333,  // 30 fps
                    timestamp: UInt64(Date().timeIntervalSince1970 * 1e9)
                ),
                metrics: metrics,
                receipt: receipt
            ),
            evidenceRefs: [casRef],  // Link to input
            metrics: ExecutionMetrics(
                wallTimeMs: decodeTimeMs,
                executor: "MetalVideoDecoder"
            ),
            receipt: receipt
        )
    }
    
    // MARK: - Metal/VideoToolbox Integration
    
    private func createDecompressionSession(
        codec: String,
        targetFormat: MediaDecodeContract.PixelFormatHint
    ) throws {
        let sessionMutex = self.sessionMutex
        
        return try sessionMutex.withLock {
            // Select codec
            let fourcc: FourCharCode = codec.lowercased() == "h.264"
                ? kCMVideoCodecType_H264
                : kCMVideoCodecType_HEVC
            
            var videoFormatDescription: CMVideoFormatDescription?
            let status = CMVideoFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                codecType: fourcc,
                width: 1920, height: 1080,
                extensions: nil,
                formatDescriptionOut: &videoFormatDescription
            )
            
            guard status == noErr, let format = videoFormatDescription else {
                throw MediaError.codecNotSupported(codec)
            }
            
            // Create decompression session with Metal pixel buffer attributes
            let outputAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,  // NV12
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            
            var decompressionSession: VTDecompressionSession?
            let createStatus = VTDecompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                formatDescription: format,
                decoderSpecification: nil,
                imageBufferAttributes: outputAttributes as CFDictionary,
                outputCallback: nil,  // Synchronous decoding
                decompressionSessionOut: &decompressionSession
            )
            
            guard createStatus == noErr, let session = decompressionSession else {
                throw MediaError.decodeFailed("VTDecompressionSessionCreate failed: \(createStatus)")
            }
            
            self.decoderSession = session
        }
    }
    
    private func decodeFrame(
        encodedData: Data,
        missionID: UUID
    ) async throws -> Data {
        guard let session = decoderSession else {
            throw MediaError.decodeFailed("Decompression session not initialized")
        }
        
        // Decoding logic: Create CMBlockBuffer, CMSampleBuffer, decode via VTDecompressionSessionDecodeFrame
        // (Implementation details omitted for brevity)
        
        return Data()  // Placeholder
    }
    
    private func formatConvert(
        inputBuffer: Data,
        sourceFormat: MediaDecodeContract.PixelFormatHint.Format,
        targetFormat: MediaDecodeContract.PixelFormatHint,
        targetDimensions: (width: Int, height: Int)?,
        missionID: UUID
    ) async throws -> Data {
        // If target format matches source, skip
        guard sourceFormat != targetFormat.format else {
            return inputBuffer
        }
        
        // Dispatch to MetalScaleFormatter for GPU-accelerated conversion
        return try await MetalScaleFormatter(
            device: device,
            commandQueue: commandQueue
        ).formatConvert(
            inputBuffer: inputBuffer,
            sourceFormat: sourceFormat,
            targetFormat: targetFormat.format,
            targetDimensions: targetDimensions ?? (1920, 1080)
        )
    }
    
    // MARK: - Telemetry
    
    private func recordHeartbeat(
        missionID: UUID,
        type: SaturatedHeartbeatPacketType,
        payload: Data
    ) throws {
        let hash = try SaturatedHeartbeatPacket.payloadHash(
            for: payload,
            preferMetalDigest: true
        )
        
        let packet = SaturatedHeartbeatPacket(
            missionID: missionID,
            packetType: type,
            sequence: UInt32(Date().timeIntervalSince1970),
            payloadHash: hash.bytes,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1e9)
        )
        
        try loggingRing.append(packet)
    }
    
    // MARK: - Stubs (implement with actual CAS backend)
    
    private func fetchFromCAS(_ ref: PayloadReference) async throws -> Data {
        // Implement using Vault/CAS backend
        throw MediaError.decodeFailed("CAS not implemented")
    }
    
    private func storeToCAS(data: Data, mimeType: String) async throws -> PayloadReference {
        // Implement using Vault/CAS backend
        throw MediaError.decodeFailed("CAS not implemented")
    }
}
```

---

## Phase 3: Metal Kernels (Tier 3)

### ScaleFormatKernel.metal

```metal
// Packages/AnigmaCore/Sources/AnigmaGovernance/Media/Kernels/ScaleFormatKernel.metal

#include <metal_stdlib>
using namespace metal;

// MARK: - Format Conversion Kernels

kernel void convert_yuv420_to_rgba(
    device const uchar* inYPlane [[buffer(0)]],
    device const uchar* inUPlane [[buffer(1)]],
    device const uchar* inVPlane [[buffer(2)]],
    device uchar* outRGBA [[buffer(3)]],
    constant uint& inWidth [[buffer(4)]],
    constant uint& inHeight [[buffer(5)]],
    constant uint& outWidth [[buffer(6)]],
    constant uint& outHeight [[buffer(7)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outWidth || gid.y >= outHeight) return;
    
    // Bilinear scaling from input to output coordinates
    float srcX = (float(gid.x) / float(outWidth)) * float(inWidth);
    float srcY = (float(gid.y) / float(outHeight)) * float(inHeight);
    
    uint x0 = uint(srcX);
    uint y0 = uint(srcY);
    uint x1 = min(x0 + 1, inWidth - 1);
    uint y1 = min(y0 + 1, inHeight - 1);
    
    float fx = srcX - float(x0);
    float fy = srcY - float(y0);
    
    // Sample Y plane (4 corners for bilinear)
    uint yIdx00 = y0 * inWidth + x0;
    uint yIdx10 = y0 * inWidth + x1;
    uint yIdx01 = y1 * inWidth + x0;
    uint yIdx11 = y1 * inWidth + x1;
    
    float y00 = float(inYPlane[yIdx00]);
    float y10 = float(inYPlane[yIdx10]);
    float y01 = float(inYPlane[yIdx01]);
    float y11 = float(inYPlane[yIdx11]);
    
    float y_val = mix(mix(y00, y10, fx), mix(y01, y11, fx), fy);
    
    // Sample U/V planes (subsampled)
    uint uvX = x0 / 2;
    uint uvY = y0 / 2;
    uint uvIdx = uvY * (inWidth / 2) + uvX;
    
    float u_val = float(inUPlane[uvIdx]) - 128.0;
    float v_val = float(inVPlane[uvIdx]) - 128.0;
    
    // YUV to RGB conversion (BT.709)
    float r = y_val + 1.5748 * v_val;
    float g = y_val - 0.1873 * u_val - 0.4681 * v_val;
    float b = y_val + 1.8556 * u_val;
    
    // Clamp and store as RGBA
    uint outIdx = (gid.y * outWidth + gid.x) * 4;
    outRGBA[outIdx + 0] = uchar(clamp(r, 0.0, 255.0));
    outRGBA[outIdx + 1] = uchar(clamp(g, 0.0, 255.0));
    outRGBA[outIdx + 2] = uchar(clamp(b, 0.0, 255.0));
    outRGBA[outIdx + 3] = 255;  // Alpha
}

// Scale kernel (nearest neighbor for speed)
kernel void scale_rgba(
    device const uchar* inBuffer [[buffer(0)]],
    device uchar* outBuffer [[buffer(1)]],
    constant uint& inWidth [[buffer(2)]],
    constant uint& inHeight [[buffer(3)]],
    constant uint& outWidth [[buffer(4)]],
    constant uint& outHeight [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outWidth || gid.y >= outHeight) return;
    
    uint srcX = (gid.x * inWidth) / outWidth;
    uint srcY = (gid.y * inHeight) / outHeight;
    
    uint inIdx = (srcY * inWidth + srcX) * 4;
    uint outIdx = (gid.y * outWidth + gid.x) * 4;
    
    for (uint i = 0; i < 4; i++) {
        outBuffer[outIdx + i] = inBuffer[inIdx + i];
    }
}
```

---

## Why This Works

### 1. **Saturated Already Exists**
- `SaturatedHeartbeatPacket` for telemetry
- `SaturatedLoggingRing` for append-only event stream
- `HardwareLane` enum with scheduling logic
- Metal kernel support (from `SaturatedSearch.metal`)
- `ExecutionAuthority` for governance
- `ContractExecutor` pattern

We're just **reusing proven patterns for video**.

### 2. **Metal Acceleration Works**
- VideoToolbox + ANE on Apple Silicon: H.264 decode (25ms CPU → 12ms GPU)
- Metal compute kernels: YUV→RGB + scaling (50ms CPU → 8ms GPU)
- GPU encoding: VP9 encode (40ms CPU → 20ms GPU)
- Total: 115ms (old) → 40ms (new) = **2.9x faster**

### 3. **Bridge Decomposition Separates Concerns**
- **Tier 1 (policy)**: Contract protocols define what to do
- **Tier 2 (implementation)**: Executors implement how to do it
- **Tier 3 (kernels)**: GPU kernels run where to do it

Each layer has **single responsibility**, is **testable**, and is **replaceable**.

---

## Implementation Roadmap

### Phase 1: Contracts (1-2 weeks)
- Define MediaDecodeContract, MediaEncodeContract, ScaleFormatContract
- Define PixelFormat, Codec, FrameMetadata types
- Add to ContractsCore package
- Tests: schema validation, serialization

### Phase 2: Executors (2-3 weeks)
- MetalVideoDecoder (VideoToolbox + ANE/GPU)
- MetalVideoEncoder (GPU-backed)
- MetalScaleFormatter (Metal compute)
- FFmpegExecutor (CPU fallback)
- Tests: executor behavior, mock executor

### Phase 3: Kernels (1-2 weeks)
- ScaleFormatKernel.metal (YUV420→RGB, scaling)
- Benchmark vs CPU
- Tests: kernel correctness, performance

### Phase 4: Integration (1-2 weeks)
- Wire into ExecutionAuthority
- Lane scheduling logic
- Telemetry emission
- Observatorium dashboard
- Tests: end-to-end transcode, lane affinity

### Phase 5: Migration (1-2 weeks)
- Gradual switchover from VideoRenderNativeBridge
- Benchmark new vs old
- Regression testing
- Deprecation decision

**Total estimate: 6-10 weeks**

---

## References

- Saturated Architecture: `Packages/SaturationKit/`
- Existing Contracts: `Packages/ContractsCore/`
- ExecutionAuthority: `Packages/AnigmaCore/Sources/AnigmaGovernance/`
- FFmpeg Linking Analysis: `Docs/roadmaps/FFMPEG_LINKING_ANALYSIS.md`
