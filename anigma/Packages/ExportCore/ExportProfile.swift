import Foundation

public enum ExportIntent: String, Sendable, Codable, CaseIterable {
    case digital
    case print
    case archive
    case accessibility
}

public struct ExportProfileSpec: Sendable, Codable, Identifiable {
    public var id: String
    public var version: String
    public var name: String
    public var description: String
    public var intent: ExportIntent
    public var pipelineSteps: [String] // IDs of steps
    public var outputFormats: [String] // "pdf", "epub", etc.
    public var constraints: [String: String] // "pageSize": "A4"

    public init(id: String, version: String, name: String, description: String, intent: ExportIntent, pipelineSteps: [String], outputFormats: [String], constraints: [String: String]) {
        self.id = id
        self.version = version
        self.name = name
        self.description = description
        self.intent = intent
        self.pipelineSteps = pipelineSteps
        self.outputFormats = outputFormats
        self.constraints = constraints
    }
}

public struct OverrideSpec: Sendable, Codable {
    public var margins: [String: Double]?
    public var outputIntent: ExportIntent?
    public var manualLayoutPatches: [LayoutPatch]?

    public init() {}
}

public struct ExportPlan: Sendable, Codable {
    public let id: String
    public let profile: ExportProfileSpec
    public let overrides: OverrideSpec
    public let inputs: [ExportInput]
    public let target: ExportTarget

    public init(id: String, profile: ExportProfileSpec, overrides: OverrideSpec, inputs: [ExportInput], target: ExportTarget) {
        self.id = id
        self.profile = profile
        self.overrides = overrides
        self.inputs = inputs
        self.target = target
    }
}
