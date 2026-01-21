//
//  OutlineStore.swift
//  AnigmaAppMac
//
//  Manages outline generation, zine creation, and document structure analysis.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
@Observable
final class OutlineStore {

    // MARK: - Properties

    /// Outline client for document generation
    private let outlineClient: OutlineClient

    /// Generated outlines
    var outlines: [OutlineResponse] = []

    /// Available zine templates
    var zineTemplates: [ZineTemplate] = []

    /// Structure analysis results
    var structureAnalysis: StructureAnalysisResponse?

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(outlineClient: OutlineClient) {
        self.outlineClient = outlineClient
    }

    // MARK: - Outline Operations

    /// Generate outline from content
    func generateOutline(content: String, depth: Int = 3) async {
        do {
            let response = try await outlineClient.generateOutline(content: content, depth: depth)
            outlines.append(response)
            showToast(
                "Outline Generated",
                "\(response.statistics.totalSections) sections",
                "list.bullet.indent"
            )
        } catch {
            showError("Outline generation failed: \(error)")
        }
    }

    /// Analyze document structure
    func analyzeStructure(filePath: String) async {
        do {
            structureAnalysis = try await outlineClient.analyzeStructure(filePath: filePath)
            if let analysis = structureAnalysis {
                showToast(
                    "Structure Analyzed",
                    "Quality: \(String(format: "%.0f", analysis.quality * 100))%",
                    "chart.bar.doc.horizontal"
                )
            }
        } catch {
            showError("Structure analysis failed: \(error)")
        }
    }

    // MARK: - Zine Operations

    /// Create zine from outline
    func createZine(outline: OutlineStructure, template: String? = nil) async {
        do {
            let response = try await outlineClient.createZine(outline: outline, template: template)
            showToast("Zine Created", "\(response.pages) pages", "book.closed")
        } catch {
            showError("Zine creation failed: \(error)")
        }
    }

    /// Export zine to format
    func exportZine(zineId: String, format: ZineExportFormat, outputPath: String) async {
        do {
            _ = try await outlineClient.exportZine(
                zineId: zineId,
                format: format,
                outputPath: outputPath
            )
            showToast("Zine Exported", outputPath, "arrow.down.doc")
        } catch {
            showError("Zine export failed: \(error)")
        }
    }

    // MARK: - Template Operations

    /// Load available zine templates
    func loadTemplates() async {
        do {
            let response = try await outlineClient.listTemplates()
            zineTemplates = response.templates
        } catch {
            showError("Failed to load templates: \(error)")
        }
    }
}
