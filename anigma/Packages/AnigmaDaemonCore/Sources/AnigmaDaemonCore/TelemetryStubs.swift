import Foundation
import AnigmaCore
import TelemetryCore

// Stub helpers for legacy telemetry usage in the daemon. These deliberately log when invoked.

extension TelemetryClient {
    /// Stub compat helper for older call sites that record DiagnosticEvent directly.
    public func record(_ event: DiagnosticEvent) async {
        logWarning("[TelemetryClient stub] record(_:) called; this path is not fully implemented and only emits a summarized event.", category: "TelemetryStubs")
        _ = await emit(
            category: .system,
            name: "diagnostic_event",
            privacyClassification: .restricted,
            values: [
                "category": .hashedToken(TelemetryHash(input: event.category)),
                "message": .hashedToken(TelemetryHash(input: event.message))
            ]
        )
    }
}

extension DiagnosticEvent {
    /// Convenience initializer for legacy call sites that passed `severity` instead of `level` and omitted correlation IDs.
    public init(
        severity: DiagnosticLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        logWarning("[DiagnosticEvent stub] Legacy initializer used; correlation and span IDs are auto-generated and this path is not fully implemented.", category: "TelemetryStubs")
        self.init(
            level: severity,
            category: category,
            message: message,
            correlationID: UUID().uuidString,
            spanID: nil,
            parentSpanID: nil,
            duration: nil,
            metadata: metadata
        )
    }
}
