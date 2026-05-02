//
//  DevelopView.swift
//  AnigmaAppMac
//
//  Main develop surface with repo navigator and workbench.
//

import SwiftUI

struct LegacyDevelopView: View {
    @State private var developState = DevelopState()

    var body: some View {
        HSplitView {
            RepoNavigator(developState: developState)
                .frame(minWidth: 240, idealWidth: 280)
            
            DevelopWorkbenchView(developState: developState)
                .frame(minWidth: 500)
        }
    }
}
struct DevelopWorkbenchView: View {
    @Bindable var developState: DevelopState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workbench")
                        .font(.headline)
                    if let repoURL = developState.repoURL {
                        Text(repoURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let fileURL = developState.selectedFileURL {
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if let fileURL = developState.selectedFileURL {
                ChunkedCodeEditorDemoView(
                    fileURL: fileURL,
                    artifactService: developState.artifactService
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Select a file to preview")
                        .font(.headline)
                    Text("Choose a file from the navigator to open it in the workbench.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
}
