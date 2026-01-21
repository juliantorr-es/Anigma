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
                    Task { await store.analyzeCode(filePath: filePath) }
                }
                .disabled(filePath.isEmpty)
            }

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

            Divider()

            Text("Symbol Search").font(.subheadline).bold()
            HStack {
                TextField("Symbol Name", text: $searchSymbol)
                    .textFieldStyle(.roundedBorder)
                Button("Find References") {
                    guard let workspace = store.activeWorkspace else { return }
                    Task {
                        await store.findSymbolReferences(symbol: searchSymbol, directory: workspace.rootURL.path)
                    }
                }
                .disabled(searchSymbol.isEmpty)
            }

            if let references = store.symbolReferences {
                Text("\(references.count) references found")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(references.references.prefix(10)) { ref in
                    VStack(alignment: .leading) {
                        Text(ref.filePath).font(.caption).bold()
                        Text("Line \(ref.location.start.line): \(ref.context)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
    }
}
