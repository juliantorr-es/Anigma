//
//  DataView.swift
//  AnigmaAppMac
//
//  Wrapper for DataWorkspaceView from DataUI.
//

import SwiftUI
import DataUI
import AnigmaClientKit
import DataEngine

struct DataView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        DataWorkspaceView(selectionId: Binding(
            get: {
                if case .entity(let id) = store.inspectorSelection {
                    return id
                }
                return nil
            },
            set: { newValue in
                if let id = newValue {
                    store.inspectorSelection = .entity(id: id)
                } else {
                    // Only clear if we were selecting an entity
                    if case .entity = store.inspectorSelection {
                        store.inspectorSelection = nil
                    }
                }
            }
        )) { title, html, url in
            Task {
                // Structured Extraction (Phase 1)
                let extractor = WebContentExtractor()
                let structured = await extractor.extract(html: html, url: url, title: title)

                // 1. Upload Structured JSON (The "Graph" Node)
                if let jsonData = try? JSONEncoder().encode(structured) {
                    await store.uploadArtifact(name: "\(title).json", data: jsonData)
                }

                // 2. Upload Raw HTML (The "Provenance" Source)
                if let data = html.data(using: .utf8) {
                    await store.uploadArtifact(name: "\(title).html", data: data)
                }

                await MainActor.run {
                    store.showToast(title: "Captured & Extracted", subtitle: title, icon: "camera.aperture")
                }
            }
        }
    }
}
