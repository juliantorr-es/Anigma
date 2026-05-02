import Foundation
import CapsuleCore
import TelemetryCore

public final class LayoutEngineCapsule: IdentifiableCapsule {
    private let wrapper: LayoutEngineCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "layout-engine-v1"
    
    public init(
        config: LayoutEngineConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "LayoutEngineCapsule.init",
            category: "layoutengine.init",
            correlationID: nil,
            tags: [
                "determinism_tier": "\(config.determinismTier)",
                "flags": "\(config.flags)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            self.wrapper = try LayoutEngineCapsuleWrapper(config: config, diagnostics: resolvedDiagnostics)
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "layoutengine.init",
                message: "Failed to create layout engine: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    public func analyzePDF(_ data: Data) throws -> [PageLayout] {
        let span = diagnostics.beginSpan(
            name: "LayoutEngineCapsule.analyzePDF",
            category: "layoutengine.analyze",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            let layouts = try wrapper.analyzePDF(data)
            span.end(status: .ok)
            return layouts
        } catch {
            diagnostics.event(
                level: .error,
                category: "layoutengine.analyze",
                message: "Layout analysis failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
}

