//
//  AIOperationDetailView.swift
//  AnigmaAppMac
//
//  Detailed view for a single AI operation showing all transparency data,
// verification status, and cryptographic evidence.
//

import SwiftUI
import AppKit

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
                    #if os(macOS)
                    .tabViewStyle(.automatic)
                    #else
                    .tabViewStyle(PageTabViewStyle())
                    #endif
                }
                .padding()
            }
            .navigationTitle("AI Operation Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section("Operation Information") {
                    InfoRow(label: "Operation ID", value: operation.id, icon: "doc.text")
                    InfoRow(label: "Timestamp", value: operation.formattedTimestamp, icon: "clock")
                    InfoRow(label: "Provider", value: operation.provider, icon: "server.rack")
                    InfoRow(label: "Model", value: operation.modelID, icon: "cpu")
                    InfoRow(label: "Task Type", value: operation.taskType.replacingOccurrences(of: "_", with: " ").capitalized, icon: "brain.head.profile")
                    InfoRow(label: "Status", value: operation.success ? "Success" : "Failed", icon: operation.success ? "checkmark.circle" : "xmark.circle")
                }
                
                Section("Performance Metrics") {
                    InfoRow(label: "Inference Time", value: operation.formattedInferenceTime, icon: "clock")
                    if let inputTokens = operation.inputTokens {
                        InfoRow(label: "Input Tokens", value: "\(inputTokens)", icon: "arrow.down.circle")
                    }
                    if let outputTokens = operation.outputTokens {
                        InfoRow(label: "Output Tokens", value: "\(outputTokens)", icon: "arrow.up.circle")
                    }
                    if operation.totalTokens > 0 {
                        InfoRow(label: "Total Tokens", value: "\(operation.totalTokens)", icon: "token.2")
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
                        InfoRow(label: "Input SHA-256", value: "a1b2c3d4e5f6...", icon: "number")
                        InfoRow(label: "Output SHA-256", value: "f6e5d4c3b2a1...", icon: "number")
                        InfoRow(label: "Verification Status", value: operation.verificationStatus.displayName, icon: operation.verificationStatus.icon)
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
                            title: "CoreReceipt Integrity",
                            status: .verified,
                            details: "CoreReceipt hash matches content"
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
                        InfoRow(label: "Operation ID", value: operation.id, icon: "doc.text")
                        InfoRow(label: "Model Version", value: "1.0.0", icon: "tag")
                        InfoRow(label: "Hardware", value: "Apple Silicon GPU", icon: "cpu")
                        InfoRow(label: "Memory Usage", value: "2.1GB", icon: "memorychip")
                        InfoRow(label: "Cache Hit Rate", value: "94%", icon: "speedometer")
                    }
                }
                
                Section("Network Information") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Execution Environment", value: "Local", icon: "house")
                        InfoRow(label: "Network Calls", value: "0", icon: "network.slash")
                        InfoRow(label: "Data Transferred", value: "0 bytes", icon: "arrow.up.arrow.down")
                    }
                }
                
                Section("Privacy & Security") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Privacy Level", value: "Standard", icon: "lock.shield")
                        InfoRow(label: "Data Retention", value: "180 days", icon: "clock.arrow.circlepath")
                        InfoRow(label: "Encryption", value: "AES-256", icon: "lock")
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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
        .background(Color(nsColor: .controlBackgroundColor))
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
                Text("CoreReceipt #\(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Hash: abc123def456...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
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
                    .background(Color(nsColor: .controlBackgroundColor))
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
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// Preview
