//
//  StorageManagementView.swift
//  AnigmaAppMac
//
//  Storage monitoring and management with 20% warning threshold.
//

import SwiftUI
import AnigmaCore

public struct StorageManagementView: View {
    @Environment(AppStore.self) private var appStore
    @State private var status: StorageMonitor.Status?
    @State private var warnings: [StorageMonitor.StorageWarning] = []
    @State private var breakdown: StorageMonitor.StorageBreakdown?
    @State private var isLoading = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let status = status {
                // Warning banner
                if !warnings.isEmpty {
                    warningBanner
                }

                // Storage overview
                storageOverview(status: status)

                // Usage chart
                if let breakdown = breakdown {
                    usageChart(breakdown: breakdown)
                }

                // Model storage breakdown
                if let breakdown = breakdown {
                    modelStorageSection(breakdown: breakdown)
                }
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading storage info...")
                    Spacer()
                }
            } else {
                ContentUnavailableView(
                    "Storage Unavailable",
                    systemImage: "externaldrive",
                    description: Text("Unable to read storage information")
                )
            }
        }
        .padding()
        .task {
            await refreshStatus()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await refreshStatus()
            }
        }
    }

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings) { warning in
                HStack {
                    Image(systemName: warning.icon)
                        .foregroundStyle(warningColor(for: warning.level))

                    VStack(alignment: .leading) {
                        Text(warning.message)
                            .font(.subheadline)
                        Text(warning.recommendedAction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(warningColor(for: warning.level).opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func storageOverview(status: StorageMonitor.Status) -> some View {
        GroupBox("Storage Overview") {
            HStack(spacing: 20) {
                // Gauge
                StorageGauge(
                    percentage: status.percentageUsed,
                    level: status.warningLevel,
                    size: 120
                )

                VStack(alignment: .leading, spacing: 8) {
                    StorageStatRow(
                        label: "Total",
                        value: status.formattedTotal,
                        color: .primary
                    )

                    StorageStatRow(
                        label: "Used",
                        value: status.formattedUsed,
                        color: Bauhaus.Color.accent
                    )

                    StorageStatRow(
                        label: "Available",
                        value: status.formattedAvailable,
                        color: status.shouldWarn ? .orange : .green
                    )

                    Divider()

                    StorageStatRow(
                        label: "Models",
                        value: status.formattedModelStorage,
                        color: .secondary
                    )
                }

                Spacer()
            }
            .padding()
        }
    }

    private func usageChart(breakdown: StorageMonitor.StorageBreakdown) -> some View {
        GroupBox("Storage Breakdown") {
            HStack(spacing: 20) {
                // Donut chart
                StorageDonutChart(breakdown: breakdown, size: 100)

                VStack(alignment: .leading, spacing: 8) {
                    ChartLegendItem(
                        color: Bauhaus.Color.accent,
                        label: "Models",
                        value: formatBytes(breakdown.modelStorageBytes)
                    )

                    ChartLegendItem(
                        color: .blue.opacity(0.7),
                        label: "Cache",
                        value: formatBytes(breakdown.cacheStorageBytes)
                    )

                    ChartLegendItem(
                        color: .gray.opacity(0.5),
                        label: "System",
                        value: formatBytes(breakdown.systemBytes)
                    )
                }

                Spacer()
            }
            .padding()
        }
    }

    private func modelStorageSection(breakdown: StorageMonitor.StorageBreakdown) -> some View {
        GroupBox("Model Storage") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(formatBytes(breakdown.modelStorageBytes)) used by models")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(breakdown.percentageModels))% of used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: breakdown.percentageModels, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Bauhaus.Color.accent)

                HStack {
                    Button("Clear Download Cache") {
                        Task {
                            await clearCache()
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
            .padding()
        }
    }

    private func warningColor(for level: StorageMonitor.WarningLevel) -> Color {
        switch level {
        case .normal:
            return .yellow
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func refreshStatus() async {
        isLoading = true

        let newStatus = await appStore.storageMonitor.getStatus()
        let newWarnings = await appStore.storageMonitor.getWarnings()
        let newBreakdown = await appStore.storageMonitor.calculateStorageBreakdown()

        await MainActor.run {
            self.status = newStatus
            self.warnings = newWarnings
            self.breakdown = newBreakdown
            self.isLoading = false
        }
    }

    private func clearCache() async {
        // Clear caches directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        for cache in caches {
            try? FileManager.default.removeItem(at: cache)
        }

        await refreshStatus()
    }
}

struct StorageGauge: View {
    let percentage: Double
    let level: StorageMonitor.WarningLevel
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Bauhaus.Color.border, lineWidth: 8)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: min(percentage, 1.0))
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                Text("used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gaugeColor: Color {
        switch level {
        case .normal:
            return Bauhaus.Color.accent
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct StorageStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct StorageDonutChart: View {
    let breakdown: StorageMonitor.StorageBreakdown
    let size: CGFloat

    var body: some View {
        ZStack {
            if breakdown.usedBytes > 0 {
                Circle()
                    .fill(Color.clear)
                    .frame(width: size, height: size)

                // Simplified representation
                GeometryReader { geometry in
                    let total = breakdown.usedBytes
                    let modelAngle = Double(breakdown.modelStorageBytes) / Double(total) * 360
                    let cacheAngle = Double(breakdown.cacheStorageBytes) / Double(total) * 360

                    ZStack {
                        Circle()
                            .trim(from: 0, to: CGFloat(modelAngle / 360))
                            .stroke(Bauhaus.Color.accent, lineWidth: 20)
                            .frame(width: size, height: size)

                        Circle()
                            .trim(from: CGFloat(modelAngle / 360), to: CGFloat((modelAngle + cacheAngle) / 360))
                            .stroke(Color.blue.opacity(0.7), lineWidth: 20)
                            .frame(width: size, height: size)
                    }
                    .rotationEffect(.degrees(-90))
                }
                .frame(width: size, height: size)
            }
        }
    }
}

struct ChartLegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
