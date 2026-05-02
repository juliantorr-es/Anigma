//
//  SurfaceStore.swift
//  AnigmaAppMac
//
//  Manages UI surfaces, rendering, visualization, and export operations.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class SurfaceStore {

    // MARK: - Properties

    /// Surface client for UI rendering and visualization
    private let surfaceClient: SurfaceClient

    /// Available surfaces
    var surfaces: [SurfaceInfo] = []

    /// Active surface metrics
    var surfaceMetrics: [String: SurfaceMetricsResponse] = [:]

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(surfaceClient: SurfaceClient) {
        self.surfaceClient = surfaceClient
    }

    // MARK: - Surface Management

    /// Load all available surfaces
    func loadSurfaces() async {
        do {
            let response = try await surfaceClient.listSurfaces()
            surfaces = response.surfaces
        } catch {
            showError("Failed to load surfaces: \(error)")
        }
    }

    /// Create a new surface
    func createSurface(name: String, type: SurfaceType, config: SurfaceConfig) async {
        do {
            _ = try await surfaceClient.createSurface(name: name, type: type, config: config)
            await loadSurfaces()
            showToast("Surface Created", name, "rectangle.on.rectangle.angled")
        } catch {
            showError("Failed to create surface: \(error)")
        }
    }

    /// Update surface configuration
    func updateSurface(id: String, config: SurfaceConfig) async {
        do {
            _ = try await surfaceClient.updateSurface(id: id, config: config)
            await loadSurfaces()
            showToast("Surface Updated", id, "rectangle.on.rectangle.angled")
        } catch {
            showError("Failed to update surface: \(error)")
        }
    }

    /// Delete a surface
    func deleteSurface(id: String) async {
        do {
            _ = try await surfaceClient.deleteSurface(id: id)
            await loadSurfaces()
            showToast("Surface Deleted", id, "trash")
        } catch {
            showError("Failed to delete surface: \(error)")
        }
    }

    // MARK: - Rendering Operations

    /// Render content to a surface
    func renderToSurface(surfaceId: String, content: RenderContent) async {
        do {
            let response = try await surfaceClient.render(surfaceId: surfaceId, content: content)
            showToast(
                "Render Complete",
                "Took \(String(format: "%.2f", response.duration))s",
                "sparkles"
            )
        } catch {
            showError("Render failed: \(error)")
        }
    }

    /// Export surface to format (PDF, PNG, SVG, HTML)
    func exportSurface(surfaceId: String, format: SurfaceExportFormat, outputPath: String) async {
        do {
            _ = try await surfaceClient.export(
                surfaceId: surfaceId,
                format: format,
                outputPath: outputPath
            )
            showToast("Export Complete", outputPath, "arrow.down.doc")
        } catch {
            showError("Export failed: \(error)")
        }
    }

    // MARK: - Visualization Operations

    /// Generate visualization from data
    func visualize(data: VisualizationData, style: VisualizationStyle) async -> VisualizationResponse? {
        do {
            return try await surfaceClient.visualize(data: data, style: style)
        } catch {
            showError("Visualization failed: \(error)")
            return nil
        }
    }

    // MARK: - Metrics Operations

    /// Load surface metrics
    func loadSurfaceMetrics(surfaceId: String) async {
        do {
            let metrics = try await surfaceClient.getMetrics(surfaceId: surfaceId)
            surfaceMetrics[surfaceId] = metrics
        } catch {
            print("Failed to load surface metrics: \(error)")
        }
    }

    // MARK: - Interactive Features

    /// Register event handler for surface
    func registerHandler(surfaceId: String, eventType: String, handler: String) async {
        do {
            _ = try await surfaceClient.registerHandler(
                surfaceId: surfaceId,
                eventType: eventType,
                handler: handler
            )
            showToast("Handler Registered", eventType, "hand.point.up")
        } catch {
            showError("Failed to register handler: \(error)")
        }
    }

    /// Unregister event handler
    func unregisterHandler(surfaceId: String, handlerId: String) async {
        do {
            _ = try await surfaceClient.unregisterHandler(
                surfaceId: surfaceId,
                handlerId: handlerId
            )
            showToast("Handler Unregistered", handlerId, "hand.point.down")
        } catch {
            showError("Failed to unregister handler: \(error)")
        }
    }
}
