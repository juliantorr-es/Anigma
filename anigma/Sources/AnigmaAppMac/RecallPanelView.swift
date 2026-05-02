//
//  RecallPanelView.swift
//  AnigmaAppMac
//
//  Search workflow UI.
//

import SwiftUI
import HarmoniaV2Contracts
import HarmoniaV2Surface

struct RecallPanelView: View {
    @ObservedObject var model: AppModel
    
    var body: some View {
        HSplitView {
            // Left: Search & Results
            VStack(spacing: 0) {
                // Search Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recall & Inspect").font(.headline)
                    
                    HStack {
                        TextField("Query...", text: $model.recallQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { model.startRecall() }
                        
                        Button("Search") {
                            model.startRecall()
                        }
                        .disabled(model.recallQuery.isEmpty || model.recallState.isSearching)
                    }
                    
                    // Options
                    DisclosureGroup("Options") {
                        VStack(alignment: .leading) {
                            HStack {
                                Stepper("Top K: \(model.recallOptions.topK)", value: Binding(
                                    get: { model.recallOptions.topK },
                                    set: { model.recallOptions = RecallOptions(topK: $0, scanLimit: model.recallOptions.scanLimit, threshold: model.recallOptions.threshold, hybrid: model.recallOptions.hybrid, explain: model.recallOptions.explain) }
                                ), in: 1...50)
                                
                                Toggle("Hybrid", isOn: Binding(
                                    get: { model.recallOptions.hybrid },
                                    set: { model.recallOptions = RecallOptions(topK: model.recallOptions.topK, scanLimit: model.recallOptions.scanLimit, threshold: model.recallOptions.threshold, hybrid: $0, explain: model.recallOptions.explain) }
                                ))
                                
                                Toggle("Explain", isOn: Binding(
                                    get: { model.recallOptions.explain },
                                    set: { model.recallOptions = RecallOptions(topK: model.recallOptions.topK, scanLimit: model.recallOptions.scanLimit, threshold: model.recallOptions.threshold, hybrid: model.recallOptions.hybrid, explain: $0) }
                                ))
                            }
                            
                            HStack {
                                Text("Scan Limit:")
                                TextField("Limit", value: Binding(
                                    get: { model.recallOptions.scanLimit ?? 0 },
                                    set: { val in model.recallOptions = RecallOptions(topK: model.recallOptions.topK, scanLimit: val > 0 ? val : nil, threshold: model.recallOptions.threshold, hybrid: model.recallOptions.hybrid, explain: model.recallOptions.explain) }
                                ), formatter: NumberFormatter())
                                .frame(width: 80)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Results List
                List(model.recallState.results) { item in
                    RecallResultRow(item: item, explain: model.recallOptions.explain)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.selectRecallResult(item)
                        }
                        .listRowBackground(model.recallState.selectedResult?.id == item.id ? Color.accentColor.opacity(0.1) : nil)
                }
                .overlay {
                    if model.recallState.isSearching {
                        ProgressView("Searching...")
                    } else if model.recallState.results.isEmpty && !model.recallQuery.isEmpty && model.recallState.stats != nil {
                        Text("No results found.")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Footer Stats
                if let stats = model.recallState.stats {
                    HStack {
                        Text("Scanned \(stats.rowsScanned) rows")
                        if let limit = stats.scanLimit {
                            Text("(limit \(limit))")
                        }
                        Spacer()
                        Text(String(format: "%.0f ms", stats.executionTime * 1000))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
            .frame(minWidth: 300)
            
            // Right: Inspector
            if let selected = model.recallState.selectedResult {
                RecallInspectorView(item: selected)
                    .frame(minWidth: 300)
            } else {
                VStack {
                    Spacer()
                    Text("Select a result to inspect")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minWidth: 300)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

struct RecallResultRow: View {
    let item: RecallItem
    let explain: Bool
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.metadata["fileName"] ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(item.content)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if explain {
                VStack(alignment: .trailing) {
                    Text(String(format: "Score: %.2f", item.similarity))
                        .fontWeight(.bold)
                    
                    if let vr = item.vectorRank {
                        Text("Vec: #\(vr)")
                    }
                    if let fr = item.ftsRank {
                        Text("FTS: #\(Int(fr))") // ftsRank is float?
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecallInspectorView: View {
    let item: RecallItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(item.metadata["fileName"] ?? "Unknown")
                        .font(.headline)
                    Text(item.metadata["filePath"] ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.content, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy Content")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                Text(item.content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            
            Divider()
            
            // Metadata
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    MetadataPill(label: "Model", value: item.metadata["embeddingModel"])
                    MetadataPill(label: "Rank", value: "#\(item.rank)")
                    MetadataPill(label: "Sim", value: String(format: "%.3f", item.similarity))
                    MetadataPill(label: "ID", value: String(item.id.prefix(8)))
                }
                .padding(8)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct MetadataPill: View {
    let label: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value ?? "-").font(.caption).fontWeight(.medium)
        }
    }
}
