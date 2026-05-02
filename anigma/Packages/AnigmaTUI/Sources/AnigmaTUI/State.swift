import Foundation
import Observation

public struct TUIState: Sendable {
    public var status: String = "Idle"
    public var mode: String = "Plan"
    public var logs: [String] = []
    public var currentModel: String = "llama-3.1"
    public var isWriteAllowed: Bool = true
    public var lastReceipt: String?

    public init() {}

    public mutating func appendLog(_ message: String) {
        logs.append(message)
        if logs.count > 50 {
            logs.removeFirst()
        }
    }
}
