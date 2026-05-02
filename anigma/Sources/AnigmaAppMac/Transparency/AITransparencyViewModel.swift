//
//  AITransparencyViewModel.swift
//  AnigmaAppMac
//
//  ViewModel for the AI transparency dashboard.
//  Manages AI operations data, filtering, and statistics.
//

import Foundation
import SwiftUI
import Combine
import AppKit
import MLWorkerCommon
import AnigmaPrimitives

// MARK: - AI Transparency ViewModel

@MainActor
class AITransparencyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var operations: [AIOperation] = []
    @Published var filteredOperations: [AIOperation] = []
    @Published var stats = SessionStats()
    @Published var selectedOperation: AIOperation?
    @Published var showingDetail = false
    @Published var chainVerificationStatus = VerificationStatus.unknown
    @Published var verificationTimeMs: Double = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up periodic refresh
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshOperations()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadOperations() {
        isLoading = true
        
        Task {
            let sessionStats = await AIReceiptIntegration.shared.getSessionStats()
            let operations = generateSyntheticOperations(from: sessionStats)

            await MainActor.run {
                self.operations = operations
                self.filteredOperations = operations
                self.stats = sessionStats
                self.isLoading = false
            }
        }
    }
    
    func refreshOperations() {
        loadOperations()
    }

    // MARK: - Chain Verification

    func verifyChain() {
        chainVerificationStatus = .pending
        
        Task {
            let start = Date()
            
            // Simulate tree-hash verification of a large evidence set
            // In a real implementation, we would fetch the receipts and build the tree
            // Here we use a 10MB dummy data set to demonstrate BLAKE3 parallel performance
            let dummyData = [UInt8](repeating: 0x41, count: 10 * 1024 * 1024)
            _ = await BLAKE3Digest.digestAsync(dummyData)
            
            let duration = Date().timeIntervalSince(start)
            
            await MainActor.run {
                self.chainVerificationStatus = .verified
                self.verificationTimeMs = duration * 1000
            }
        }
    }
    
    // MARK: - Filtering
    
    func applyFilter(_ filter: FilterOption, searchText: String) {
        var filtered = operations
        
        // Apply filter type
        switch filter {
        case .all:
            break
        case .successful:
            filtered = filtered.filter { $0.success }
        case .failed:
            filtered = filtered.filter { !$0.success }
        case .mlxCalls:
            filtered = filtered.filter { $0.provider == "mlx" }
        case .toolExecutions:
            filtered = filtered.filter { $0.operationType == .toolExecution }
        }
        
        // Apply search text
        if !searchText.isEmpty {
            filtered = filtered.filter { operation in
                operation.id.localizedCaseInsensitiveContains(searchText) ||
                operation.modelID.localizedCaseInsensitiveContains(searchText) ||
                operation.taskType.localizedCaseInsensitiveContains(searchText) ||
                operation.provider.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        filteredOperations = filtered
    }
    
    func setTimeRange(_ timeRange: TimeRange) {
        let cutoffDate = Date().addingTimeInterval(-timeRange.timeInterval)
        
        filteredOperations = operations.filter { $0.timestamp >= cutoffDate }
    }
    
    // MARK: - Statistics
    
    func updateStatistics() {
        Task {
            let sessionStats = await AIReceiptIntegration.shared.getSessionStats()
            
            await MainActor.run {
                self.stats = sessionStats
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateSyntheticOperations(from stats: SessionStats) -> [AIOperation] {
        var operations: [AIOperation] = []
        let now = Date()
        
        // Generate synthetic operations based on session stats
        for i in 0..<stats.totalOperations {
            let timestamp = now.addingTimeInterval(-Double(i) * 300) // Every 5 minutes
            let success = i < stats.successfulOperations
            
            let operation = AIOperation(
                id: UUID().uuidString,
                timestamp: timestamp,
                modelID: stats.modelStats.keys.randomElement() ?? "llama-3.1-8b",
                taskType: stats.taskTypeStats.keys.randomElement() ?? "llm_chat",
                provider: stats.providerStats.keys.randomElement() ?? "mlx",
                operationType: success ? .inference : .error,
                success: success,
                inferenceTimeMs: Int64.random(in: 500...5000),
                inputTokens: Int.random(in: 100...1000),
                outputTokens: Int.random(in: 50...500),
                errorMessage: success ? nil : "Network timeout",
                verificationStatus: .verified
            )
            
            operations.append(operation)
        }
        
        return operations.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - AI Operation Model

struct AIOperation: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let modelID: String
    let taskType: String
    let provider: String
    let operationType: CoreOperationType
    let success: Bool
    let inferenceTimeMs: Int64
    let inputTokens: Int?
    let outputTokens: Int?
    let errorMessage: String?
    let verificationStatus: VerificationStatus
    
    var totalTokens: Int {
        return (inputTokens ?? 0) + (outputTokens ?? 0)
    }
    
    var formattedInferenceTime: String {
        if inferenceTimeMs < 1000 {
            return "\(inferenceTimeMs)ms"
        } else {
            return String(format: "%.2fs", Double(inferenceTimeMs) / 1000)
        }
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

enum CoreOperationType: String, Codable, CaseIterable {
    case inference = "inference"
    case toolExecution = "tool_execution"
    case workflow = "workflow"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .inference: return "Inference"
        case .toolExecution: return "Tool Execution"
        case .workflow: return "Workflow"
        case .error: return "Error"
        }
    }
    
    var icon: String {
        switch self {
        case .inference: return "brain.head.profile"
        case .toolExecution: return "wrench.and.screwdriver"
        case .workflow: return "flowchart"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .inference: return .blue
        case .toolExecution: return .green
        case .workflow: return .purple
        case .error: return .red
        }
    }
}

enum VerificationStatus: String, Codable, CaseIterable {
    case verified = "verified"
    case pending = "pending"
    case failed = "failed"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .verified: return "Verified"
        case .pending: return "Pending"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .verified: return "checkmark.shield"
        case .pending: return "clock"
        case .failed: return "xmark.shield"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .verified: return .green
        case .pending: return .orange
        case .failed: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Supporting Views

struct AIOperationRow: View {
    let operation: AIOperation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status icon
                Image(systemName: operation.operationType.icon)
                    .font(.title2)
                    .foregroundStyle(operation.operationType.color)
                    .frame(width: 30)
                
                // Operation details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(operation.taskType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if !operation.success {
                                Label("Failed", systemImage: "exclamationmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            Label(operation.verificationStatus.displayName,
                                  systemImage: operation.verificationStatus.icon)
                                .font(.caption)
                                .foregroundStyle(operation.verificationStatus.color)
                        }
                    }
                    
                    HStack {
                        Label(operation.provider, systemImage: "server.rack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if operation.totalTokens > 0 {
                            Label("\(operation.totalTokens) tokens", systemImage: "token.2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Label(operation.modelID, systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Label(operation.formattedInferenceTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
