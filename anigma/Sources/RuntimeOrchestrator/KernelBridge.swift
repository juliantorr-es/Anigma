import Foundation
import AnigmaNativeShims

public final class KernelBridge: @unchecked Sendable {
  private var kernel: UnsafeMutablePointer<anigma_kernel_t>?

  public init(config: Data) throws {
    var out: UnsafeMutablePointer<anigma_kernel_t>?
    let status = config.withUnsafeBytes { buf in
      anigma_kernel_create(anigma_blob_t(ptr: buf.bindMemory(to: UInt8.self).baseAddress, len: buf.count), &out)
    }
    guard status == ANIGMA_OK, let k = out else { throw KernelError.createFailed(status) }
    self.kernel = k
  }

  deinit {
    if let k = kernel { anigma_kernel_destroy(k) }
  }

  public func applyDiffBatch(_ batch: Data) throws -> Data {
    guard let k = kernel else { throw KernelError.notInitialized }
    var out = anigma_mut_blob_t(ptr: nil, len: 0)
    let status = batch.withUnsafeBytes { buf in
      anigma_kernel_apply_diff_batch(k, anigma_blob_t(ptr: buf.bindMemory(to: UInt8.self).baseAddress, len: buf.count), &out)
    }
    guard status == ANIGMA_OK else { throw KernelError.callFailed(status) }
    let data = Data(bytes: out.ptr!, count: out.len)
    anigma_kernel_free_blob(out)
    return data
  }

  public func stepFixed(ticks: UInt32) throws {
    guard let k = kernel else { throw KernelError.notInitialized }
    var out = anigma_mut_blob_t(ptr: nil, len: 0)
    let status = anigma_kernel_step_fixed(k, ticks, &out)
    guard status == ANIGMA_OK else { throw KernelError.callFailed(status) }
    anigma_kernel_free_blob(out)
  }

  public func renderPlan(viewportRequest: Data) throws -> Data {
    guard let k = kernel else { throw KernelError.notInitialized }
    var out = anigma_mut_blob_t(ptr: nil, len: 0)
    let status = viewportRequest.withUnsafeBytes { buf in
      anigma_kernel_render_plan(k, anigma_blob_t(ptr: buf.bindMemory(to: UInt8.self).baseAddress, len: buf.count), &out)
    }
    guard status == ANIGMA_OK else { throw KernelError.callFailed(status) }
    let data = Data(bytes: out.ptr!, count: out.len)
    anigma_kernel_free_blob(out)
    return data
  }

  public func stateHash() throws -> [UInt8] {
    guard let k = kernel else { throw KernelError.notInitialized }
    var hash = [UInt8](repeating: 0, count: 32)
    let status = anigma_kernel_state_hash(k, &hash)
    guard status == ANIGMA_OK else { throw KernelError.callFailed(status) }
    return hash
  }
}

public enum KernelError: Error {
  case notInitialized
  case createFailed(anigma_status_t)
  case callFailed(anigma_status_t)
}
