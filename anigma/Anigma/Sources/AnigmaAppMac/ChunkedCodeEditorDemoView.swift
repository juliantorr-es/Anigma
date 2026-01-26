//
//  ChunkedCodeEditorDemoView.swift
//  AnigmaAppMac
//
//  Workbench code editor using DevelopumArtifactService.
//

import SwiftUI

struct ChunkedCodeEditorDemoView: View {
    let fileURL: URL
    let artifactService: DevelopumArtifactService

    @State private var chunks: [CodeChunk] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(fileURL.lastPathComponent)
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        ForEach(chunks) { chunk in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Lines \(chunk.lineRange.lowerBound)-\(chunk.lineRange.upperBound)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(chunk.text)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: fileURL) {
            await loadChunks()
        }
    }

    private func loadChunks() async {
        isLoading = true
        do {
            let loaded = try await artifactService.loadChunks(from: fileURL)
            chunks = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            chunks = []
        }
        isLoading = false
    }
}
