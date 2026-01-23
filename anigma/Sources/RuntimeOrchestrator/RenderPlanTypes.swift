import Foundation
import AnigmaNativeShims

public struct RenderPlanView {
  public let bytes: Data

  public init(_ bytes: Data) { self.bytes = bytes }

  public func withUnsafePlan<T>(_ body: (UnsafePointer<anigma_plan_header_t>) throws -> T) rethrows -> T {
    try bytes.withUnsafeBytes { raw in
      let base = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
      let header = base.assumingMemoryBound(to: anigma_plan_header_t.self)
      return try body(header)
    }
  }
}
