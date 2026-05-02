//
//  IndexPanelView.swift
//  AnigmaAppMac
//
//  Indexing workflow UI.
//

import SwiftUI
import HarmoniaV2Surface

struct IndexPanelView: View {
    @ObservedObject var model: AppModel
    @State private var isShowingFileImporter = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Indexing Workflow")
                .font(.headline)
            
            if let project = model.projects.first(where: { $0.id == model.selectedProjectId }) {
                Text("Target: \(project.name) (\(project.embeddingModel))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No project selected").font(.caption).foregroundColor(.red)
            }
            
            Divider()
            
            // Folder Selection
            HStack {
                Button("Choose Folder...") {
                    isShowingFileImporter = true
                }
                .disabled(model.indexingState.phase == .running)
                .fileImporter(
                    isPresented: $isShowingFileImporter,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            model.selectFolder(url: url)
                        }
                    case .failure(let error):
                        print("File importer failed: \(error.localizedDescription)")
                    }
                }
                
                if let url = model.indexingState.selectedFolder {
                    Text(url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.primary)
                } else {
                    Text("No folder selected").foregroundColor(.secondary)
                }
            }
            
            // Controls
            HStack {
                Toggle("Dry Run", isOn: $model.indexingState.dryRun)
                    .disabled(model.indexingState.phase == .running)
                
                Spacer()
                
                if model.indexingState.phase == .running {
                    Button("Cancel") {
                        model.cancelIndex()
                    }
                } else {
                    Button("Start Indexing") {
                        model.startIndex()
                    }
                    .disabled(model.indexingState.selectedFolder == nil || model.selectedProjectId == nil)
                }
            }
            
            Divider()
            
            // Progress
            if let progress = model.indexingState.progress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(progress.phase)
                            .fontWeight(.bold)
                        Spacer()
                        if progress.totalFiles > 0 {
                            Text("\(Int((Double(progress.filesProcessed) / Double(progress.totalFiles)) * 100))%")
                        }
                    }
                    
                    ProgressView(value: Double(progress.filesProcessed), total: Double(max(1, progress.totalFiles)))
                    
                    HStack {
                        Text("\(progress.filesProcessed) / \(progress.totalFiles) files")
                        Spacer()
                        Text("\(progress.chunksWritten) chunks")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("Time: \(String(format: "%.1fs", model.indexingState.elapsed))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Ready to index.")
                    .foregroundColor(.secondary)
            }
            
            // Log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(model.indexingState.logLines, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(line.contains("Error") || line.contains("Denied") ? .red : .primary)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .onChange(of: model.indexingState.logLines.count) { _ in
                    if let last = model.indexingState.logLines.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
