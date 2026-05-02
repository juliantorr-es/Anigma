//
//  SurfaceClient.swift
//  AnigmaHostMac
//
//  Surface interface client for harmonia-surface binary.
//  Manages UI rendering, visualization, and interactive surfaces.
//

import Foundation
import ContractsCore

/// Client for harmonia-surface binary integration
public struct SurfaceClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/harmonia-surface") {
        self.binaryPath = binaryPath
    }

    // MARK: - Surface Management

    /// List all available surfaces
    public func listSurfaces() async throws -> SurfaceListResponse {
        let output = try await execute(["list", "--format", "json"])
        return try JSONDecoder().decode(SurfaceListResponse.self, from: output)
    }

    /// Create a new surface
    public func createSurface(name: String, type: SurfaceType, config: SurfaceConfig) async throws -> SurfaceResponse {
        let configJSON = try JSONEncoder().encode(config)
        let configString = String(data: configJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["create", "--name", name, "--type", type.rawValue, "--config", configString, "--format", "json"])
        return try JSONDecoder().decode(SurfaceResponse.self, from: output)
    }

    /// Update surface configuration
    public func updateSurface(id: String, config: SurfaceConfig) async throws -> SurfaceResponse {
        let configJSON = try JSONEncoder().encode(config)
        let configString = String(data: configJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["update", "--id", id, "--config", configString, "--format", "json"])
        return try JSONDecoder().decode(SurfaceResponse.self, from: output)
    }

    /// Delete a surface
    public func deleteSurface(id: String) async throws -> SurfaceSuccessResponse {
        let output = try await execute(["delete", "--id", id, "--format", "json"])
        return try JSONDecoder().decode(SurfaceSuccessResponse.self, from: output)
    }

    // MARK: - Rendering

    /// Render content to a surface
    public func render(surfaceId: String, content: RenderContent) async throws -> RenderResponse {
        let contentJSON = try JSONEncoder().encode(content)
        let contentString = String(data: contentJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["render", "--surface", surfaceId, "--content", contentString, "--format", "json"])
        return try JSONDecoder().decode(RenderResponse.self, from: output)
    }

    /// Export surface to format (PDF, PNG, SVG)
    public func export(surfaceId: String, format: SurfaceExportFormat, outputPath: String) async throws -> SurfaceExportResponse {
        let output = try await execute(["export", "--surface", surfaceId, "--format", format.rawValue, "--output", outputPath, "--format", "json"])
        return try JSONDecoder().decode(SurfaceExportResponse.self, from: output)
    }

    // MARK: - Visualization

    /// Generate visualization from data
    public func visualize(data: VisualizationData, style: VisualizationStyle) async throws -> VisualizationResponse {
        let dataJSON = try JSONEncoder().encode(data)
        let styleJSON = try JSONEncoder().encode(style)
        let dataString = String(data: dataJSON, encoding: .utf8) ?? "{}"
        let styleString = String(data: styleJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["visualize", "--data", dataString, "--style", styleString, "--format", "json"])
        return try JSONDecoder().decode(VisualizationResponse.self, from: output)
    }

    /// Get surface metrics
    public func getMetrics(surfaceId: String) async throws -> SurfaceMetricsResponse {
        let output = try await execute(["metrics", "--surface", surfaceId, "--format", "json"])
        return try JSONDecoder().decode(SurfaceMetricsResponse.self, from: output)
    }

    // MARK: - Interactive Features

    /// Register event handler for surface
    public func registerHandler(surfaceId: String, eventType: String, handler: String) async throws -> HandlerResponse {
        let output = try await execute(["handler", "register", "--surface", surfaceId, "--event", eventType, "--handler", handler, "--format", "json"])
        return try JSONDecoder().decode(HandlerResponse.self, from: output)
    }

    /// Unregister event handler
    public func unregisterHandler(surfaceId: String, handlerId: String) async throws -> SurfaceSuccessResponse {
        let output = try await execute(["handler", "unregister", "--surface", surfaceId, "--handler-id", handlerId, "--format", "json"])
        return try JSONDecoder().decode(SurfaceSuccessResponse.self, from: output)
    }

    // MARK: - Execution

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
            throw SurfaceClientError.executionFailed(message: errorMessage)
        }

        return outputData
    }
}

// MARK: - Types

public enum SurfaceType: String, Codable {
    case canvas
    case graph
    case timeline
    case dashboard
    case report
}

public enum SurfaceExportFormat: String, Codable {
    case pdf
    case png
    case svg
    case html
}

public struct SurfaceConfig: Codable {
    public var width: Int?
    public var height: Int?
    public var backgroundColor: String?
    public var interactive: Bool?
    public var theme: String?

    public init(width: Int? = nil, height: Int? = nil, backgroundColor: String? = nil, interactive: Bool? = nil, theme: String? = nil) {
        self.width = width
        self.height = height
        self.backgroundColor = backgroundColor
        self.interactive = interactive
        self.theme = theme
    }
}

public struct RenderContent: Codable {
    public let elements: [RenderElement]
    public let layout: String?

    public init(elements: [RenderElement], layout: String? = nil) {
        self.elements = elements
        self.layout = layout
    }
}

public struct RenderElement: Codable {
    public let type: String
    public let data: [String: String]
    public let style: [String: String]?

    public init(type: String, data: [String: String], style: [String: String]? = nil) {
        self.type = type
        self.data = data
        self.style = style
    }
}

public struct VisualizationData: Codable {
    public let series: [[String: String]]  // Changed from Any to String for Codable compliance
    public let labels: [String]?

    public init(series: [[String: String]], labels: [String]? = nil) {
        self.series = series
        self.labels = labels
    }
}

public struct VisualizationStyle: Codable {
    public let chartType: String
    public let colors: [String]?
    public let annotations: [String]?

    public init(chartType: String, colors: [String]? = nil, annotations: [String]? = nil) {
        self.chartType = chartType
        self.colors = colors
        self.annotations = annotations
    }
}

// MARK: - Responses

public struct SurfaceListResponse: Codable {
    public let surfaces: [SurfaceInfo]
}

public struct SurfaceInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: SurfaceType
    public let createdAt: Date
}

public struct SurfaceResponse: Codable {
    public let id: String
    public let name: String
    public let type: SurfaceType
    public let config: SurfaceConfig
}

public struct RenderResponse: Codable {
    public let success: Bool
    public let renderId: String
    public let duration: Double
}

public struct SurfaceExportResponse: Codable {
    public let success: Bool
    public let outputPath: String
    public let fileSize: Int
}

public struct VisualizationResponse: Codable {
    public let id: String
    public let imageData: String // Base64 encoded
    public let metadata: [String: String]
}

public struct SurfaceMetricsResponse: Codable {
    public let renders: Int
    public let exports: Int
    public let avgRenderTime: Double
    public let lastUpdated: Date
}

public struct HandlerResponse: Codable {
    public let handlerId: String
    public let registered: Bool
}

public struct SurfaceSuccessResponse: Codable {
    public let success: Bool
    public let message: String?
}

// MARK: - Errors

public enum SurfaceClientError: Error, LocalizedError {
    case executionFailed(message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Surface client execution failed: \(message)"
        case .invalidResponse:
            return "Invalid response from harmonia-surface"
        }
    }
}
