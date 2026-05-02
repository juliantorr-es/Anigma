import Foundation
import OSLog

private let errorLogger = Logger(subsystem: "com.anigma.app", category: "errors")

/// Categorized errors for user-facing display.
enum AnigmaUIError: LocalizedError {
    case daemonUnavailable
    case operationTimeout
    case accessDenied(reason: String)
    case resourceNotFound(type: String, id: String)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .daemonUnavailable:
            return "The Anigma daemon is unreachable. Please ensure it's running in Settings."
        case .operationTimeout:
            return "The operation timed out. Please try again."
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .resourceNotFound(let type, let id):
            return "\(type) '\(id)' not found."
        case .unexpected(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Helper for retrying async operations with exponential backoff.
func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    backoffMultiplier: Double = 2.0,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 1
    var delay = initialDelay

    while true {
        do {
            return try await operation()
        } catch {
            if attempt >= maxAttempts {
                throw error
            }

            errorLogger.warning(
                "Operation failed (attempt \(attempt, privacy: .public)): \(error.localizedDescription, privacy: .public). Retrying in \(String(format: "%.1f", delay), privacy: .public)s"
            )
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            attempt += 1
            delay *= backoffMultiplier
        }
    }
}
