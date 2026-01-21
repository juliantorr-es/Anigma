//
//  OutlineClient.swift
//  AnigmaHostMac
//
//  Outlineum zine generation and outline management client.
//

import Foundation

public struct OutlineClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/outlineum-zine") {
        self.binaryPath = binaryPath
    }

    public func generateOutline(content: String, depth: Int = 3) async throws -> OutlineResponse {
        let output = try await execute(["generate", "--content", content, "--depth", "\(depth)", "--format", "json"])
        return try JSONDecoder().decode(OutlineResponse.self, from: output)
    }

    public func createZine(outline: OutlineStructure, template: String? = nil) async throws -> ZineResponse {
        let outlineJSON = try JSONEncoder().encode(outline)
        let outlineString = String(data: outlineJSON, encoding: .utf8) ?? "{}"
        var args = ["create", "--outline", outlineString, "--format", "json"]
        if let template = template {
            args.append(contentsOf: ["--template", template])
        }
        let output = try await execute(args)
        return try JSONDecoder().decode(ZineResponse.self, from: output)
    }

    public func exportZine(zineId: String, format: ZineExportFormat, outputPath: String) async throws -> ZineExportResponse {
        let output = try await execute(["export", "--id", zineId, "--format", format.rawValue, "--output", outputPath, "--format", "json"])
        return try JSONDecoder().decode(ZineExportResponse.self, from: output)
    }

    public func listTemplates() async throws -> TemplateListResponse {
        let output = try await execute(["templates", "list", "--format", "json"])
        return try JSONDecoder().decode(TemplateListResponse.self, from: output)
    }

    public func analyzeStructure(filePath: String) async throws -> StructureAnalysisResponse {
        let output = try await execute(["analyze", "--file", filePath, "--format", "json"])
        return try JSONDecoder().decode(StructureAnalysisResponse.self, from: output)
    }

    private func execute(_ arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw OutlineClientError.executionFailed(message: errorMessage)
        }

        return outputData
    }
}

public enum ZineExportFormat: String, Codable {
    case pdf
    case epub
    case markdown
    case html
}

public struct OutlineStructure: Codable {
    public let title: String
    public let sections: [OutlineSection]

    public init(title: String, sections: [OutlineSection]) {
        self.title = title
        self.sections = sections
    }
}

public struct OutlineSection: Codable {
    public let heading: String
    public let level: Int
    public let content: String?
    public let subsections: [OutlineSection]?

    public init(heading: String, level: Int, content: String? = nil, subsections: [OutlineSection]? = nil) {
        self.heading = heading
        self.level = level
        self.content = content
        self.subsections = subsections
    }
}

public struct OutlineResponse: Codable {
    public let outline: OutlineStructure
    public let statistics: OutlineStatistics
}

public struct OutlineStatistics: Codable {
    public let totalSections: Int
    public let maxDepth: Int
    public let wordCount: Int
}

public struct ZineResponse: Codable {
    public let zineId: String
    public let pages: Int
    public let createdAt: Date
    public let previewUrl: String?
}

public struct ZineExportResponse: Codable {
    public let success: Bool
    public let outputPath: String
    public let fileSize: Int
}

public struct TemplateListResponse: Codable {
    public let templates: [ZineTemplate]
}

public struct ZineTemplate: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let pageSize: String
}

public struct StructureAnalysisResponse: Codable {
    public let outline: OutlineStructure
    public let quality: Double
    public let suggestions: [String]
}

public enum OutlineClientError: Error, LocalizedError {
    case executionFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Outline client execution failed: \(message)"
        }
    }
}
