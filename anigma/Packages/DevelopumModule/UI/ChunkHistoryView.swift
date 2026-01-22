//
//  ChunkHistoryView.swift
//  DevelopumModule
//
//  View for displaying the history of a specific code chunk.
//

import SwiftUI
import AnigmaCore

public struct ChunkHistoryView: View {
    let history: [ChunkHistoryItem]
    let currentHash: String
    let onClose: () -> Void
    
    public init(history: [ChunkHistoryItem], currentHash: String, onClose: @escaping () -> Void) {
        self.history = history
        self.currentHash = currentHash
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chunk History")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(history, id: \.versionId) { item in
                        HistoryItemRow(item: item, isCurrent: item.chunkHash == currentHash)
                        Divider()
                    }
                }
            }
        }
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

struct HistoryItemRow: View {
    let item: ChunkHistoryItem
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(isCurrent ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                
                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(item.chunkHash.prefix(6))
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(item.versionId.prefix(8))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isCurrent ? Color.accentColor.opacity(0.05) : Color.clear)
    }
}
