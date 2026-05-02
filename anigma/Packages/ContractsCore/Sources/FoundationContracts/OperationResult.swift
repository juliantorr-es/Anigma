import AnigmaPrimitives
import Foundation

/// Canonical operation envelope for long-running tasks.
public struct OperationResult<Payload: Codable & Sendable>: Codable, Sendable {
    public enum State: String, Codable, Sendable {
        case running
        case success
        case failure
        case cancelled
    }

    public struct Progress: Codable, Sendable {
        public let percent: Double
        public let message: String?

        public init(percent: Double, message: String? = nil) {
            self.percent = percent
            self.message = message
        }
    }

    public struct Failure: Codable, Sendable {
        public let code: String
        public let message: String
        public let recoveryHint: String?

        public init(code: String, message: String, recoveryHint: String? = nil) {
            self.code = code
            self.message = message
            self.recoveryHint = recoveryHint
        }

        public init(error: PlatformError) {
            self.init(code: error.code, message: error.message, recoveryHint: error.hint)
        }

        public var asAnigmaError: PlatformError {
            PlatformError(code: code, message: message, hint: recoveryHint)
        }
    }

    public let id: UUID
    public let kind: String
    public let startTime: Date
    public let endTime: Date?
    public let state: State
    public let payload: Payload?
    public let progress: Progress?
    public let failure: Failure?

    public init(
        id: UUID = UUID(),
        kind: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        state: State,
        payload: Payload? = nil,
        progress: Progress? = nil,
        failure: Failure? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startTime = startTime
        self.endTime = endTime
        self.state = state
        self.payload = payload
        self.progress = progress
        self.failure = failure
    }
}

/// Unified error schema for operations.
public struct PlatformError: Codable, Error, Sendable, Equatable {
    public let code: String
    public let message: String
    public let hint: String?

    public init(code: String, message: String, hint: String? = nil) {
        self.code = code
        self.message = message
        self.hint = hint
    }
}

extension OperationResult.Progress: Equatable {}
extension OperationResult.Failure: Equatable {}
extension OperationResult: Equatable where Payload: Equatable {}
