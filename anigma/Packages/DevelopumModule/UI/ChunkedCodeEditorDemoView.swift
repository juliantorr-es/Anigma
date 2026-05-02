//
//  ChunkedCodeEditorDemoView.swift
//  DevelopumModule
//
//  Demo view for the chunk-based code editor capabilities.
//

import SwiftUI
import AnigmaCore
import AnigmaPrimitives
import AnigmaSidecar

public struct ChunkedCodeEditorDemoView: View {
    @State private var content: String = """
    // Sample code for chunking
    func hello() {
        print("Hello World")
    }
    
    struct User {
        let name: String
        let age: Int
    }
    
    extension User {
        func greet() {
            print("Hi, I'm \\(name)")
        }
    }
    """
    @State private var chunks: [CodeChunk] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var selectedChunkHistory: ChunkHistoryPayload?
    @State private var showGraph: Bool = false
    
    @State private var chunkingMode: ChunkingMode = .semantic
    
    private let artifactService: DevelopumArtifactService
    private let qualityService = QualityEnforcementService()
    
    public enum ChunkingMode: String, CaseIterable, Identifiable {
        case content = "Content (Rabin)"
        case semantic = "Semantic (Heuristic)"
        
        public var id: String { rawValue }
    }
    
    public init(artifactService: DevelopumArtifactService) {
        self.artifactService = artifactService
    }
    
    public var body: some View {
        VStack {
            HStack {
                Text("Chunk-Based Editor Demo")
                    .font(.headline)
                
                Picker("Mode", selection: $chunkingMode) {
                    ForEach(ChunkingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Spacer()
                
                Button(action: enforceQuality) {
                    Label("Best Practices", systemImage: "checkmark.shield")
                }
                .disabled(isProcessing)
                
                Button(action: { showGraph.toggle() }) {
                    Label("Graph", systemImage: "arrow.triangle.branch")
                }
                .disabled(chunks.isEmpty)
                .popover(isPresented: $showGraph) {
                    ChunkGraphView(chunks: chunks)
                        .frame(width: 400, height: 500)
                }
                
                Button(action: chunkCode) {
                    if isProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Visualize Chunks", systemImage: "square.grid.3x3")
                    }
                }
                .disabled(isProcessing)
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 0) {
                // Editor
                MonacoEditorView(
                    fileUri: "anigma://demo.swift",
                    content: content,
                    languageId: "swift",
                    chunkBoundaries: chunks.isEmpty ? nil : chunks,
                    onBridgeMessage: handleBridgeMessage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Chunk History (Side Panel)
                if let history = selectedChunkHistory {
                    ChunkHistoryView(
                        history: history.history,
                        currentHash: history.currentChunkHash,
                        onClose: { selectedChunkHistory = nil }
                    )
                    .transition(.move(edge: .trailing))
                }
                
                // Chunk List (Side Panel)
                if !chunks.isEmpty && selectedChunkHistory == nil {
                    VStack {
                        List(chunks) { chunk in
                            VStack(alignment: .leading) {
                                Text(chunk.hash.prefix(8))
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)
                                Text("Offset: \(chunk.offset), Len: \(chunk.length)")
                                    .font(.caption2)
                            }
                        }
                        
                        Divider()
                        
                        Button("Verify Reassembly") {
                            verifyReassembly()
                        }
                        .controlSize(.small)
                        .padding()
                    }
                    .frame(width: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
    }
    
    private func handleBridgeMessage(_ message: DevelopumBridgeMessage) {
        if case .chunkAction(let payload) = message.payload {
            // In a real app, this would be handled by the System -> State -> View binding.
            // For this demo, we simulate the response by directly calling history service if possible,
            // or just showing a mock if we don't have full system wiring.
            // However, the System handles the action and *should* send back a message.
            // But we don't have the System wired to *this specific view* directly via a publisher yet.
            // We rely on the `MonacoEditorView` callback which catches messages coming *from* JS.
            
            // Wait, `onBridgeMessage` catches messages FROM JS.
            // So we caught the 'chunkAction'.
            
            // To show history, we need to query it.
            // Since we have `artifactService` which has `databaseService` inside (if we expose it or add a helper),
            // let's add a helper to `artifactService` or just mock it for the UI demo responsiveness
            // if we can't easily reach `DevelopumHistoryService`.
            
            // Actually, `DevelopumArtifactService` is available.
            // Let's assume for the demo we want to show the UI even if the backend system isn't fully running the loop.
            // But we *did* implement `handleChunkAction` in `DevelopumEditorSystem`.
            // The issue is `DevelopumEditorSystem` logs it but doesn't have a way to callback *this view*.
            
            // So for the DEMO VIEW specifically, let's implement the history fetch here directly
            // so the user sees the result immediately without needing the full ECS loop running.
            
            Task {
                // Simulate history fetch or use a direct service if available
                // We don't have direct access to HistoryService here easily without DI.
                // Let's Mock it for visual verification of the UI component.
                
                let mockHistory = [
                    ChunkHistoryItem(versionId: UUID().uuidString, timestamp: Date(), chunkHash: payload.hash),
                    ChunkHistoryItem(versionId: UUID().uuidString, timestamp: Date().addingTimeInterval(-3600), chunkHash: "old_hash_123"),
                    ChunkHistoryItem(versionId: UUID().uuidString, timestamp: Date().addingTimeInterval(-7200), chunkHash: "older_hash_456")
                ]
                
                await MainActor.run {
                    self.selectedChunkHistory = ChunkHistoryPayload(
                        currentChunkHash: payload.hash,
                        history: mockHistory
                    )
                }
            }
        }
    }
    
    private func enforceQuality() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let (newCode, changes) = try await qualityService.enforceBestPractices(code: content, language: "swift")
                
                await MainActor.run {
                    if !changes.isEmpty {
                        self.content = newCode
                        self.errorMessage = "Applied \(changes.count) quality improvements."
                    } else {
                        self.errorMessage = "Code already meets best practices."
                    }
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Quality enforcement failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func chunkCode() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result: [CodeChunk]
                switch chunkingMode {
                case .content:
                    // Call the artifact service to chunk the file (Content-based)
                    result = try await artifactService.chunkFile(content: content)
                case .semantic:
                    // Call the artifact service to chunk the file (Semantic)
                    result = try await artifactService.semanticChunkFile(content: content)
                }
                
                await MainActor.run {
                    self.chunks = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Chunking failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func verifyReassembly() {
        Task {
            do {
                // 1. Create Virtual Document (simulated repo ID)
                let repoId = UUID()
                let vDoc = try await artifactService.createVirtualDocument(
                    repoId: repoId,
                    filePath: "demo.swift",
                    chunks: chunks
                )
                
                // 2. Assemble from Virtual Document Record
                let reassembled = try await artifactService.assembleDocument(from: vDoc)
                
                await MainActor.run {
                    if reassembled == content {
                        print("Reassembly Successful!")
                    } else {
                        self.errorMessage = "Reassembly Mismatch!"
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Reassembly Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
