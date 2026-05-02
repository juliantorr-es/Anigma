//
//  AssistantIntegrationExample.swift
//  AnigmaAppMac
//
//  Example showing how to integrate AssistantView into the app.
//  This file is for reference only - not compiled into the app.
//

import SwiftUI

// MARK: - Example 1: Add to HarmoniaRootView as a Tab

struct HarmoniaRootViewWithAssistant: View {
    @StateObject private var model: AppModel
    
    init() {
        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbDir = appSupport.appendingPathComponent("Anigma")
        try! FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("harmonia_v3.postgres").path
        let client = LocalAppClient(databasePath: dbPath)
        _model = StateObject(wrappedValue: AppModel(client: client))
    }
    
    var body: some View {
        HSplitView {
            // Sidebar (unchanged)
            VStack {
                Text("Projects").font(.headline).padding(.top)
                ProjectBootstrapView(model: model)
                Spacer()
                StatusPanelView(model: model)
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Main Content with Assistant Tab
            VStack {
                if let projectId = model.selectedProjectId {
                    HStack {
                        Text("Project: \(model.projects.first(where: { $0.id == projectId })?.name ?? projectId)")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    TabView {
                        // Existing tabs
                        IndexPanelView(model: model)
                            .tabItem { Label("Index", systemImage: "doc.text.magnifyingglass") }
                        
                        RecallPanelView(model: model)
                            .tabItem { Label("Search", systemImage: "magnifyingglass") }
                        
                        MemoPanelView(model: model)
                            .tabItem { Label("Memo", systemImage: "square.and.pencil") }
                        
                        // NEW: Assistant tab
                        AssistantView()
                            .tabItem { Label("Assistant", systemImage: "sparkles") }
                    }
                    .padding()
                } else {
                    Text("Select a project to begin")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Example 2: Standalone Window

struct AssistantWindow: View {
    var body: some View {
        AssistantView()
            .frame(minWidth: 800, minHeight: 600)
            .background(Bauhaus.Color.background)
    }
}

// To add as a new window in AnigmaApp.swift:
/*
@main
struct AnigmaApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            HarmoniaRootView()
        }
        
        // Assistant window
        WindowGroup("Assistant") {
            AssistantWindow()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Assistant Query") {
                    // Open new assistant window
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
*/

// MARK: - Example 3: Replace Main View

struct AssistantOnlyApp: View {
    var body: some View {
        AssistantView()
            .navigationTitle("Anigma Assistant")
    }
}

// In AnigmaApp.swift:
/*
WindowGroup {
    AssistantOnlyApp()
}
*/

// MARK: - Example 4: Connect to Existing Data

extension AssistantState {
    // Add method to connect with existing HarmoniaV2Surface database
    func connectToHarmonia(model: AppModel) {
        // Wire up context from existing project
        Task {
            if let projectId = model.selectedProjectId,
               let project = model.projects.first(where: { $0.id == projectId }) {
                
                localModelName = project.embeddingModel
                
                // Could query actual document/embedding counts here
                // documentCount = try? await model.client.getDocumentCount(projectId: projectId)
                // embeddingCount = try? await model.client.getEmbeddingCount(projectId: projectId)
            }
        }
    }
    
    // Add method to use recall for source retrieval
    func retrieveSources(for query: String, model: AppModel) async -> [SourceReference] {
        guard let projectId = model.selectedProjectId else { return [] }
        
        // Use existing recall infrastructure
        let options = RecallOptions(topK: 5, scanLimit: 100, threshold: 0.7, hybrid: true, explain: false)
        
        do {
            let results = try await model.client.recall(
                query: query,
                projectId: projectId,
                options: options,
                principal: model.principal
            )
            
            // Convert RecallItem to SourceReference
            return results.items.map { item in
                SourceReference(
                    title: item.metadata["fileName"] ?? "Unknown",
                    path: item.metadata["filePath"],
                    excerpt: String(item.content.prefix(200)),
                    similarity: item.similarity
                )
            }
        } catch {
            print("Failed to retrieve sources: \(error)")
            return []
        }
    }
}

// MARK: - Example 5: Wire Local LLM (Placeholder)

extension AssistantState {
    // This would connect to actual local LLM inference
    func runLocalInference(query: String, context: [SourceReference]) async -> AnalysisResult {
        // TODO: Replace with actual MLX/llama.cpp integration
        
        // Placeholder structure:
        // 1. Build prompt with context
        // STUB_TRACK: assistant-local-llm – Local LLM integration not implemented
        print("⚠️  STUB INVOKED: AssistantState.runLocalInference()")
        print("   MLX/llama.cpp integration not implemented - using placeholder response")
        let contextText = context.map { $0.excerpt ?? "" }.joined(separator: "\n\n")
        let prompt = """
        Context:
        \(contextText)
        
        Question: \(query)
        
        Answer:
        """
        
        // 2. Run inference placeholder until local LLM integration is wired in
        let response = "Placeholder response. Integrate with local LLM here."
        
        // 3. Generate receipt
        let receipt = Receipt(
            operationType: "local_inference",
            timestamp: Date(),
            hash: prompt.hash.description // Simplified
        )
        
        // 4. Return result with provenance
        let result = AnalysisResult(
            id: UUID().uuidString,
            content: response,
            confidence: 0.8,
            sourceIds: context.map { $0.id },
            timestamp: Date()
        )
        
        // Store receipt
        if var analysis = currentAnalysis {
            analysis.receipts.append(receipt)
            analysis.sources = context
            currentAnalysis = analysis
        }
        
        return result
    }
}
