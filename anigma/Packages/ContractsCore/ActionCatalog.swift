//
//  ActionCatalog.swift
//  ContractsCore
//
//  Contract definition for ActionCatalog in ContractsCore.
//

import Foundation

/// Defines the expected type and requirement for an intent parameter.
public struct ActionParameterSchema: Sendable, Codable {
    public enum ParamType: String, Sendable, Codable {
        case string
        case number
        case bool
        case object
        case array
        case any
    }

    /// UI hint for parameter input type.
    public enum ParamVariant: String, Sendable, Codable {
        case text        // Single-line text
        case longText    // Multi-line text
        case artifact    // Select artifact from vault
        case choice      // One of selected options
        case number      // Numerical input
        case toggle      // Boolean toggle
        case date        // Date picker
    }

    public let type: ParamType
    public let variant: ParamVariant
    public let required: Bool
    public let displayName: String
    public let description: String?
    public let placeholder: String?
    public let options: [String]? // Used for .choice variant

    public init(
        _ type: ParamType,
        variant: ParamVariant = .text,
        required: Bool = true,
        displayName: String,
        description: String? = nil,
        placeholder: String? = nil,
        options: [String]? = nil
    ) {
        self.type = type
        self.variant = variant
        self.required = required
        self.displayName = displayName
        self.description = description
        self.placeholder = placeholder
        self.options = options
    }
}

/// Declarative definition of an action's policy.
public struct ActionDefinition: Sendable {
    public let name: String
    public let family: String
    public let displayName: String
    public let description: String
    public let helpText: String?
    public let icon: String? // SF Symbol name
    public let parameters: [String: ActionParameterSchema]

    /// Deterministic function to map an intent to a target resource URI.
    /// Used for scope enforcement.
    public let resourceMapper: @Sendable (ActionIntent) -> String

    public init(
        name: String,
        family: String,
        displayName: String,
        description: String,
        helpText: String? = nil,
        icon: String? = nil,
        parameters: [String: ActionParameterSchema] = [:],
        resourceMapper: @escaping @Sendable (ActionIntent) -> String
    ) {
        self.name = name
        self.family = family
        self.displayName = displayName
        self.description = description
        self.helpText = helpText
        self.icon = icon
        self.parameters = parameters
        self.resourceMapper = resourceMapper
    }
}

/// The registry of all valid actions in the system.
/// This acts as the "Law" for the Authority.
public struct ActionCatalog: Sendable {

    public static let shared = ActionCatalog()

    // In a real system, this might be loaded from plugins or modules.
    public let actions: [String: ActionDefinition]

    public init() {
        var registry: [String: ActionDefinition] = [:]

        // --- Core Artifact Tools (Powered by anigmad) ---

        registry["ocr"] = ActionDefinition(
            name: "ocr",
            family: "core",
            displayName: "OCR Text Extraction",
            description: "Extract text from images or scanned PDFs.",
            helpText: "Uses Tesseract engine to perform optical character recognition. Output is a plain text artifact linked to the source.",
            icon: "text.viewfinder",
            parameters: [
                "artifactId": ActionParameterSchema(.string, variant: .artifact, displayName: "Input Image", description: "The image artifact to process.")
            ]
        )            { _ in "system:/compute/ocr" }

        registry["pdf.heavy"] = ActionDefinition(
            name: "pdf.heavy",
            family: "core",
            displayName: "Advanced PDF Toolkit",
            description: "Merge, split, or optimize PDF documents.",
            helpText: "High-fidelity PDF processing using the heavy sidecar service.",
            icon: "doc.on.doc",
            parameters: [
                "pdfs": ActionParameterSchema(.array, variant: .artifact, displayName: "PDF Files", description: "One or more PDFs to process."),
                "operation": ActionParameterSchema(.string, variant: .choice, displayName: "Operation", description: "Merge multiple files or split a single file.", options: ["merge", "split"]),
                "page": ActionParameterSchema(.number, variant: .number, required: false, displayName: "Split Page", description: "Page number to split at (required for 'split' operation).")
            ]
        )            { _ in "system:/compute/pdf" }

        registry["office.render"] = ActionDefinition(
            name: "office.render",
            family: "core",
            displayName: "Office Quick Look",
            description: "Convert Word, Excel, or PowerPoint to PDF/Images.",
            icon: "doc.plaintext",
            parameters: [
                "document": ActionParameterSchema(.string, variant: .artifact, displayName: "Office Document"),
                "format": ActionParameterSchema(.string, variant: .choice, displayName: "Output Format", options: ["pdf", "png"]),
                "page": ActionParameterSchema(.number, variant: .number, required: false, displayName: "Page Number", description: "Specific page to render for image output.")
            ]
        )            { _ in "system:/compute/office" }

        registry["nlp.translate"] = ActionDefinition(
            name: "nlp.translate",
            family: "core",
            displayName: "Smart Translator",
            description: "Translate text between languages with context preservation.",
            icon: "character.book.closed",
            parameters: [
                "text": ActionParameterSchema(.string, variant: .longText, displayName: "Source Text"),
                "source": ActionParameterSchema(.string, variant: .choice, displayName: "From", options: ["en", "es", "fr", "de", "zh", "ja"]),
                "target": ActionParameterSchema(.string, variant: .choice, displayName: "To", options: ["en", "es", "fr", "de", "zh", "ja"])
            ]
        )            { _ in "system:/compute/translate" }

        registry["nlp.summarize"] = ActionDefinition(
            name: "nlp.summarize",
            family: "core",
            displayName: "Deep Summary",
            description: "Generate a semantic summary of one or more documents.",
            icon: "text.quote",
            parameters: [
                "artifacts": ActionParameterSchema(.array, variant: .artifact, displayName: "Documents"),
                "length": ActionParameterSchema(.string, variant: .choice, displayName: "Summary Length", options: ["brief", "detailed", "bullet-points"])
            ]
        )            { _ in "system:/compute/summarize" }

        // --- Core Family (Legacy/Internal) ---

        registry["hello_action"] = ActionDefinition(
            name: "hello_action",
            family: "ui",
            displayName: "Hello Test",
            description: "A test action for verification.",
            parameters: [
                "message": ActionParameterSchema(.string, required: false, displayName: "Message")
            ]
        )            { intent in "ui:/\(intent.action.rawValue)" }

        // --- Filesystem Family (Governed) ---

        registry["filesystem.read"] = ActionDefinition(
            name: "filesystem.read",
            family: "filesystem",
            displayName: "Read File",
            description: "Read a file from disk.",
            parameters: [
                "path": ActionParameterSchema(.string, displayName: "File Path"),
                "encoding": ActionParameterSchema(.string, required: false, displayName: "Encoding")
            ]
        )            { intent in
                if case .string(let path) = intent.parameters["path"] { return "file://\(path)" }
                return "file:/"
            }

        self.actions = registry
    }

    public func definition(for actionRef: ActionRef) -> ActionDefinition? {
        guard let def = actions[actionRef.rawValue] else { return nil }
        return def
    }
}
