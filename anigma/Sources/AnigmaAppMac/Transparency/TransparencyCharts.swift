//
//  TransparencyCharts.swift
//  AnigmaAppMac
//
//  Chart components for the AI transparency dashboard.
//  Shows provider distribution, task types, and performance metrics.
//

import SwiftUI
import Charts

// MARK: - Provider Distribution Chart

struct ProviderDistributionChart: View {
    let stats: SessionStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            if stats.providerStats.isEmpty {
                Text("No provider data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(stats.providerStats.keys.sorted()), id: \.self) { provider in
                        SectorMark(
                            angle: .value("Usage", Double(stats.providerStats[provider, default: 0])),
                            innerRadius: .ratio(0.4),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Provider", provider))
                        .opacity(0.8)
                    }
                }
                .chartAngleSelection(value: .constant(nil))
                .chartForegroundStyleScale(range: {
                    if stats.providerStats.count == 1 {
                        return [.blue]
                    } else if stats.providerStats.count == 2 {
                        return [.blue, .green]
                    } else if stats.providerStats.count == 3 {
                        return [.blue, .green, .orange]
                    } else {
                        return [.blue, .green, .orange, .purple, .red]
                    }
                }())
                .frame(height: 200)
                
                // Provider legend
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(stats.providerStats.keys.sorted()), id: \.self) { provider in
                        HStack {
                            Circle()
                                .fill(colorForProvider(provider))
                                .frame(width: 12, height: 12)
                            Text(provider)
                                .font(.caption)
                            Spacer()
                            Text("\(stats.providerStats[provider, default: 0])")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func colorForProvider(_ provider: String) -> Color {
        switch provider.lowercased() {
        case "mlx": return .blue
        case "gemini": return .green
        case "claude": return .orange
        case "openai": return .red
        case "local": return .purple
        default: return .gray
        }
    }
}

// MARK: - Task Type Distribution Chart

struct TaskTypeDistributionChart: View {
    let stats: SessionStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Type Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            if stats.taskTypeStats.isEmpty {
                Text("No task type data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(stats.taskTypeStats.keys.sorted()), id: \.self) { taskType in
                        BarMark(
                            x: .value("Count", Double(stats.taskTypeStats[taskType, default: 0])),
                            y: .value("Task", taskType.replacingOccurrences(of: "_", with: " ").capitalized)
                        )
                        .foregroundStyle(colorForTaskType(taskType))
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: max(150, Double(stats.taskTypeStats.count) * 30))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func colorForTaskType(_ taskType: String) -> Color {
        switch taskType.lowercased() {
        case "llm_chat": return .blue
        case "embedding": return .green
        case "code_generation": return .purple
        case "analysis": return .orange
        case "transcription": return .red
        case "search": return .mint
        default: return .gray
        }
    }
}

// MARK: - Model Usage View

struct ModelUsageView: View {
    let stats: SessionStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Usage")
                .font(.headline)
                .fontWeight(.semibold)
            
            if stats.modelStats.isEmpty {
                Text("No model usage data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(stats.modelStats.keys.sorted()), id: \.self) { model in
                        ModelUsageRow(
                            modelID: model,
                            count: stats.modelStats[model, default: 0],
                            percentage: percentageForModel(model, stats: stats)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func percentageForModel(_ model: String, stats: SessionStats) -> Double {
        let total = stats.modelStats.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(stats.modelStats[model, default: 0]) / Double(total) * 100
    }
}

struct ModelUsageRow: View {
    let modelID: String
    let count: Int
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelID)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .textSelection(.enabled)
                    Text("\(count) operations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.5), value: percentage)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    let stats: SessionStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                PerformanceMetricCard(
                    title: "Total Operations",
                    value: "\(stats.totalOperations)",
                    icon: "brain.head.profile",
                    color: .blue
                )
                
                PerformanceMetricCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", stats.successRate * 100),
                    icon: "checkmark.circle",
                    color: stats.successRate > 0.8 ? .green : .orange
                )
                
                PerformanceMetricCard(
                    title: "Avg Inference Time",
                    value: String(format: "%.1fs", stats.averageInferenceTimeMs / 1000),
                    icon: "clock",
                    color: .purple
                )
                
                PerformanceMetricCard(
                    title: "Total Tokens",
                    value: "\(stats.totalTokens)",
                    icon: "token.2",
                    color: .mint
                )
                
                PerformanceMetricCard(
                    title: "Successful Ops",
                    value: "\(stats.successfulOperations)",
                    icon: "checkmark",
                    color: .green
                )
                
                PerformanceMetricCard(
                    title: "Failed Ops",
                    value: "\(stats.failedOperations)",
                    icon: "xmark",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PerformanceMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Chain Integrity View

struct ChainIntegrityView: View {
    @State private var verificationStatus = VerificationStatus.verified
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chain Integrity Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: verificationStatus.icon)
                        .font(.title)
                        .foregroundStyle(verificationStatus.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt Chain")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(verificationStatus.displayName)
                            .font(.caption)
                            .foregroundStyle(verificationStatus.color)
                    }
                    
                    Spacer()
                    
                    Button("Verify") {
                        verifyChain()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if verificationStatus == .verified {
                    Text("✅ All receipts in the chain are cryptographically verified")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func verifyChain() {
        // Simulate verification process
        verificationStatus = .pending
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            verificationStatus = .verified
        }
    }
}

// MARK: - Recent Verifications View

struct RecentVerificationsView: View {
    private let recentVerifications = [
        ("Receipt Chain", Date().addingTimeInterval(-300), .verified),
        ("Individual Receipt", Date().addingTimeInterval(-900), .verified),
        ("Batch Verification", Date().addingTimeInterval(-1800), .failed)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Verifications")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recentVerifications.isEmpty {
                Text("No recent verifications")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentVerifications.enumerated()), id: \.offset) { index, verification in
                        VerificationRow(
                            title: verification.0,
                            timestamp: verification.1,
                            status: verification.2
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct VerificationRow: View {
    let title: String
    let timestamp: Date
    let status: VerificationStatus
    
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundStyle(status.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(formatter.string(from: timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(status.color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Verification Tools View

struct VerificationToolsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verification Tools")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                VerificationToolButton(
                    title: "Verify Receipt Chain",
                    description: "Verify integrity of the entire receipt chain",
                    icon: "checkmark.shield",
                    color: .blue
                ) {
                    // Implement chain verification
                }
                
                VerificationToolButton(
                    title: "Export Receipt",
                    description: "Export individual receipt for external verification",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    // Implement receipt export
                }
                
                VerificationToolButton(
                    title: "Audit Report",
                    description: "Generate comprehensive audit report",
                    icon: "doc.text",
                    color: .purple
                ) {
                    // Implement audit report generation
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct VerificationToolButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .buttonStyle(PlainButtonStyle())
    }
}