import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import ContractsCore
import InferenceCore
import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import SaturationKit

/// A Swift bridge to the native kernel scene graph, handling serialization of mutations.
public final class SceneGraph {
    private var kernel: anigma_kernel_instance_t?
    private var pendingDiffs: [Data] = []
    private let loggingRing: SaturatedLoggingRing

    public init() throws {
        let ring = try SaturatedLoggingRing(capacity: 1024)
        self.loggingRing = ring

        let ctx = anigma_ctx_t(operation_id: 0, budget_cpu_ms: 0, budget_mem_bytes: 0, user_data: nil)
        var instance: anigma_kernel_instance_t?

        var cRing = ring.cEvidenceRing()
        let status = anigma_kernel_initialize(ctx, anigma_blob_t(ptr: nil, size: 0), &cRing, &instance)

        guard status == ANIGMA_OK, let k = instance else {
            throw SceneGraphError.initializationFailed(status)
        }
        self.kernel = k
    }

    public func getLoggingRing() -> SaturatedLoggingRing {
        return loggingRing
    }
// ...
    deinit {
        if let k = kernel {
            anigma_kernel_shutdown(k)
        }
    }
    
    public func addNode(id: anigma_entity_id_t) {
        let header = anigma_diff_header_t(
            op: UInt8(ANIGMA_DIFF_ATTACH.rawValue), 
            target_count: 1, 
            flags: 0, 
            payload_size: UInt32(MemoryLayout<anigma_diff_attach_t>.size)
        )
        let attach = anigma_diff_attach_t(entity_id: id, component_type: 0, component_size: 0, component_data: ())
        
        var data = Data()
        withUnsafeBytes(of: header) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: attach) { data.append(contentsOf: $0) }
        pendingDiffs.append(data)
    }
    
    public func updateTransform(id: anigma_entity_id_t, transform: anigma_transform_t) {
        let header = anigma_diff_header_t(
            op: UInt8(ANIGMA_DIFF_TRANSFORM.rawValue), 
            target_count: 1, 
            flags: 0, 
            payload_size: UInt32(MemoryLayout<anigma_diff_transform_t>.size)
        )
        let xform = anigma_diff_transform_t(entity_id: id, transform: transform)
        
        var data = Data()
        withUnsafeBytes(of: header) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: xform) { data.append(contentsOf: $0) }
        pendingDiffs.append(data)
    }
    
    public func removeNode(id: anigma_entity_id_t) {
        let header = anigma_diff_header_t(
            op: UInt8(ANIGMA_DIFF_DETACH.rawValue), 
            target_count: 1, 
            flags: 0, 
            payload_size: UInt32(MemoryLayout<anigma_entity_id_t>.size)
        )
        
        var data = Data()
        withUnsafeBytes(of: header) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: id) { data.append(contentsOf: $0) }
        pendingDiffs.append(data)
    }
    
    public func flush() throws {
        guard !pendingDiffs.isEmpty else { return }
        
        let batchHeader = anigma_diff_batch_t(
            diff_count: UInt32(pendingDiffs.count), 
            schema_version: 1, 
            sequence_id: UInt64.random(in: 0...UInt64.max),
            diffs: ()
        )
        
        var batchData = Data()
        withUnsafeBytes(of: batchHeader) { batchData.append(contentsOf: $0) }
        for diff in pendingDiffs {
            batchData.append(diff)
        }
        
        let ctx = anigma_ctx_t(operation_id: 0, budget_cpu_ms: 0, budget_mem_bytes: 0, user_data: nil)
        var receipt = anigma_mut_blob_t(ptr: nil, size: 0)
        
        let status = batchData.withUnsafeBytes { buf in
            anigma_kernel_apply_diff_batch(
                kernel!, 
                ctx, 
                anigma_blob_t(ptr: buf.bindMemory(to: UInt8.self).baseAddress, size: buf.count), 
                &receipt
            )
        }
        
        if receipt.ptr != nil {
            anigma_kernel_free_blob(receipt)
        }
        
        guard status == ANIGMA_OK else {
            throw SceneGraphError.applyFailed(status)
        }
        
        pendingDiffs.removeAll()
    }
}

public enum SceneGraphError: Error {
    case initializationFailed(anigma_status_t)
    case applyFailed(anigma_status_t)
}
