//
//  ChunkGraphView.swift
//  DevelopumModule
//
//  Visualizes the structure of a Virtual Document as a relational graph.
//

import SwiftUI
import AnigmaCore

public struct ChunkGraphView: View {
    let chunks: [CodeChunk]
    
    public init(chunks: [CodeChunk]) {
        self.chunks = chunks
    }
    
    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 20) {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, chunk in
                    ChunkNode(chunk: chunk, index: index)
                    
                    if index < chunks.count - 1 {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ChunkNode: View {
    let chunk: CodeChunk
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Chunk \(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(chunk.hash.prefix(6))
                    .font(.caption2)
                    .monospaced()
                    .padding(2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Divider()
            
            Text("Length: \(chunk.length)")
                .font(.caption2)
            
            Text("Offset: \(chunk.offset)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(width: 180)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
