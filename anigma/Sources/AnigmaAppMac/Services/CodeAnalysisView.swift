//
//  CodeAnalysisView.swift
//  AnigmaAppMac
//
//  AST Services and code analysis UI.
//

import SwiftUI

struct CodeAnalysisView: View {
    @Environment(AppStore.self) private var store
    @State private var filePath = ""
    @State private var searchSymbol = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Code Analysis & AST Services")
                .font(.headline)

            HStack {
                TextField("File Path", text: $filePath)
                    .textFieldStyle(.roundedBorder)
                Button("Analyze") {
                    // analyzeCode method not yet implemented
                }
                .disabled(true)
            }

            // Analysis results disabled - astAnalysisResults not available on AppStore
            /*
            if let results = store.astAnalysisResults {
                VStack(alignment: .leading) {
                    Text("Analysis Results").font(.subheadline).bold()

                    HStack {
                        Label("\(results.metrics.linesOfCode) LOC", systemImage: "doc.text")
                        Label("Complexity: \(results.metrics.complexity)", systemImage: "chart.bar")
                        Label("Quality: \(Int(results.metrics.maintainability * 100))%", systemImage: "checkmark.seal")
                    }
                    .font(.caption)

                    if !results.issues.isEmpty {
                        List(results.issues) { issue in
                            HStack {
                                Image(systemName: issue.severity == "error" ? "exclamationmark.circle" : "exclamationmark.triangle")
                                    .foregroundStyle(issue.severity == "error" ? .red : .orange)
                                VStack(alignment: .leading) {
                                    Text(issue.message)
                                        .font(.caption)
                                    Text("Line \(issue.location.start.line)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }
            }
            */

            Divider()

            Text("Symbol Search").font(.subheadline).bold()
            HStack {
                TextField("Symbol Name", text: $searchSymbol)
                    .textFieldStyle(.roundedBorder)
                Button("Find References") {
                    // findSymbolReferences method not yet implemented
                }
                .disabled(true)
            }

        }
        .padding()
    }
}
