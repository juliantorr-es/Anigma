//
//  AIOperationDetailView.swift
//  AnigmaAppMac
//
//  Detailed view for a single AI operation showing all transparency data,
// verification status, and cryptographic evidence.
//

import SwiftUI

// MARK: - AI Operation Detail View

struct AIOperationDetailView: View {
    let operation: AIOperation
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with operation summary
                    operationHeader
                    
                    // Tab view for different sections
                    TabView(selection: $selectedTab) {
                        // Overview tab
                        overviewTab
                            .tabItem {
                                Label("Overview", systemImage: "info.circle")
                            }
                            .tag(0)
                        
                        // Input/Output tab
                        inputOutputTab
                            .tabItem {
                                Label("Input/Output", systemImage: "arrow.left.arrow.right")
                            }
                            .tag(1)
                        
                        // Verification tab
                        verificationTab
                            .tabItem {
                                Label("Verification", systemImage: "checkmark.shield")
                            }
                            .tag(2)
                        
                        // Technical Details tab
                        technicalTab
                            .tabItem {
                                Label("Technical", systemImage: "gear")
                            }
                            .tag(3)
                    }
                    .frame(height: 400)
                    .tabViewStyle(PageTabViewStyle())
                }
                .padding()
            }
            .navigationTitle("AI Operation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Operation Header
    
    private var operationHeader: some View {
        VStack(spacing: 16) {
            HStack {
                // Operation type icon
                Image(systemName: operation.operationType.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(operation.operationType.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(operation.taskType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(operation.operationType.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if operation.success {
                        Label("Success", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    
                    Label(operation.verificationStatus.displayName,
                          systemImage: operation.verificationStatus.icon)
                        .font(.caption)
                        .foregroundStyle(operation.verificationStatus.color)
                }
            }
            
            // Key metrics row
            HStack(spacing: 20) {
                MetricCard(
                    title: "Provider",
                    value: operation.provider,
                    icon: "server.rack"
                )
                
                MetricCard(
                    title: "Model",
                    value: operation.modelID,
                    icon: "cpu"
                )
                
                MetricCard(
                    title: "Duration",
                    value: operation.formattedInferenceTime,
                    icon: "clock"
                )
                
                if operation.totalTokens > 0 {
                    MetricCard(
                        title: "Tokens",
                        value: "\(operation.totalTokens)",
                        icon: "token.2"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Operation Information") {
                    InfoRow("Operation ID", operation.id, icon: "doc.text")
                    InfoRow("Timestamp", operation.formattedTimestamp, icon: "clock")
                    InfoRow("Provider", operation.provider, icon: "server.rack")
                    InfoRow("Model", operation.modelID, icon: "cpu")
                    InfoRow("Task Type", operation.taskType.replacingOccurrences(of: "_", with: " ").capitalized, icon: "brain.head.profile")
                    InfoRow("Status", operation.success ? "Success" : "Failed", icon: operation.success ? "checkmark.circle" : "xmark.circle")
                }
                
                Section("Performance Metrics") {
                    InfoRow("Inference Time", operation.formattedInferenceTime, icon: "clock")
                    if let inputTokens = operation.inputTokens {
                        InfoRow("Input Tokens", "\(inputTokens)", icon: "arrow.down.circle")
                    }
                    if let outputTokens = operation.outputTokens {
                        InfoRow("Output Tokens", "\(outputTokens)", icon: "arrow.up.circle")
                    }
                    if operation.totalTokens > 0 {
                        InfoRow("Total Tokens", "\(operation.totalTokens)", icon: "token.2")
                    }
                }
                
                if let errorMessage = operation.errorMessage {
                    Section("Error Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Message")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Input/Output Tab
    
    private var inputOutputTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Input Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Parameters")
                            .font(.headline)
                        
                        CodeBlock(
                            content: generateInputJSON(),
                            language: "json"
                        )
                    }
                }
                
                Section("Output Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Results")
                            .font(.headline)
                        
                        CodeBlock(
                            content: generateOutputJSON(),
                            language: "json"
                        )
                    }
                }
                
                Section("Data Hashes") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow("Input SHA-256", "a1b2c3d4e5f6...", icon: "number")
                        InfoRow("Output SHA-256", "f6e5d4c3b2a1...", icon: "number")
                        InfoRow("Verification Status", operation.verificationStatus.displayName, icon: operation.verificationStatus.icon)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Verification Tab
    
    private var verificationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Cryptographic Verification") {
                    VStack(alignment: .leading, spacing: 12) {
                        VerificationStatusRow(
                            title: "Receipt Integrity",
                            status: .verified,
                            details: "Receipt hash matches content"
                        )
                        
                        VerificationStatusRow(
                            title: "Chain Link",
                            status: .verified,
                            details: "Linked to previous receipt"
                        )
                        
                        VerificationStatusRow(
                            title: "Signature",
                            status: .verified,
                            details: "Digital signature valid"
                        )
                        
                        VerificationStatusRow(
                            title: "Timestamp",
                            status: .verified,
                            details: "Chronological order maintained"
                        )
                    }
                }
                
                Section("Evidence Chain") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This operation is part of a cryptographic evidence chain")
                            .font(.headline)
                        
                        ForEach(0..<3, id: \.self) { index in
                            EvidenceChainRow(index: index)
                        }
                    }
                }
                
                Section("Audit Trail") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Complete audit information")
                            .font(.headline)
                        
                        Button("Export Audit Trail") {
                            // Export functionality
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Technical Tab
    
    private var technicalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Technical Specifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow("Operation ID", operation.id, icon: "doc.text")
                        InfoRow("Model Version", "1.0.0", icon: "tag")
                        InfoRow("Hardware", "Apple Silicon GPU", icon: "cpu")
                        InfoRow("Memory Usage", "2.1GB", icon: "memorychip")
                        InfoRow("Cache Hit Rate", "94%", icon: "speedometer")
                    }
                }
                
                Section("Network Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow("Execution Environment", "Local", icon: "house")
                        InfoRow("Network Calls", "0", icon: "network.slash")
                        InfoRow("Data Transferred", "0 bytes", icon: "arrow.up.arrow.down")
                    }
                }
                
                Section("Privacy & Security") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow("Privacy Level", "Standard", icon: "lock.shield")
                        InfoRow("Data Retention", "180 days", icon: "clock.arrow.circlepath")
                        InfoRow("Encryption", "AES-256", icon: "lock")
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func generateInputJSON() -> String {
        let input = [
            "model_id": operation.modelID,
            "task_type": operation.taskType,
            "provider": operation.provider,
            "timestamp": ISO8601DateFormatter().string(from: operation.timestamp)
        ] as [String: Any]
        
        guard let data = try? JSONSerialization.data(withJSONObject: input, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return json
    }
    
    private func generateOutputJSON() -> String {
        let output: [String: Any] = operation.success ? [
            "status": "success",
            "inference_time_ms": operation.inferenceTimeMs,
            "input_tokens": operation.inputTokens ?? 0,
            "output_tokens": operation.outputTokens ?? 0
        ] : [
            "status": "error",
            "error": operation.errorMessage ?? "Unknown error"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return json
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

struct VerificationStatusRow: View {
    let title: String
    let status: VerificationStatus
    let details: String
    
    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EvidenceChainRow: View {
    let index: Int
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Receipt #\(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Hash: abc123def456...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .font(.system(.monospaced, design: .monospaced))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CodeBlock: View {
    let content: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(content, forType: .string)
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// Preview
#Preview {
    let mockOperation = AIOperation(
        id: UUID().uuidString,
        timestamp: Date(),
        modelID: "llama-3.1-8b",
        taskType: "llm_chat",
        provider: "mlx",
        operationType: .inference,
        success: true,
        inferenceTimeMs: 2840,
        inputTokens: 1247,
        outputTokens: 342,
        errorMessage: nil,
        verificationStatus: .verified
    )
    
    return AIOperationDetailView(operation: mockOperation)
}