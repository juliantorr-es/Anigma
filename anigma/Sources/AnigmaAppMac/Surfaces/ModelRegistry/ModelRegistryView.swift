//
//  ModelRegistryView.swift
//  AnigmaAppMac
//
//  Model Registry browser - shows installed models, trust tiers, compatibility.
//  Phase 5: UX that doesn't lie to users.
//

import SwiftUI
import ContractsCore

public struct ModelRegistryView: View {
    @Environment(AppStore.self) private var appStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
            ContentUnavailableView(
                "Model Registry",
                systemImage: "square.stack.3d.up",
                description: Text("Model registry UI coming soon")
            )
            GroupBox("Manage Models (Placeholder)") {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Use the CLI or MCP tools to import, verify, and run models for now.")
                        .font(Bauhaus.Font.body)
                    Text("CLI: anigma-cli models list | import | run | embed")
                        .font(Bauhaus.Font.mono)
                    Text("MCP: download_model, import_local_model, run_model, run_embedding")
                        .font(Bauhaus.Font.mono)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Bauhaus.Grid.unit)
            }
        }
        .padding(Bauhaus.Grid.x4)
        .background(Bauhaus.Color.background)
    }
}
