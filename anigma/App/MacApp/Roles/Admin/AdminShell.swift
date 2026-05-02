//
//  AdminShell.swift
//  AnigmaAppMac
//
//  The "Control Room" for Administrators.
//  Focus: System Health, Policy, Risk Management.
//  Structure: Governance Strip + Dashboard (Grid).
//

import SwiftUI

struct AdminShell: View {
    @Environment(AppStore.self) private var store

    // MARK: - Computed Metrics

    private var jobSuccessRate: (value: String, trend: String, color: Color) {
        let total = store.jobs.count
        let succeeded = store.jobs.filter { $0.status.uppercased() == "SUCCEEDED" || $0.status.uppercased() == "COMPLETED" }.count
        let failed = store.jobs.filter { $0.status.uppercased() == "FAILED" }.count

        guard total > 0 else { return ("—", "No jobs", Bauhaus.Color.active) }

        let rate = Double(succeeded) / Double(total) * 100
        let rateStr = String(format: "%.1f%%", rate)
        let color: Color = rate >= 95 ? Bauhaus.Color.success : (rate >= 80 ? Bauhaus.Color.warning : Bauhaus.Color.error)
        let trend = failed == 0 ? "No failures" : "\(failed) failed"

        return (rateStr, trend, color)
    }

    private var activeWorkers: (value: String, trend: String) {
        let running = store.runningJobsCount
        return ("\(running)", running > 0 ? "Processing" : "Idle")
    }

    private var storageUsage: (value: String, trend: String, color: Color) {
        let artifactCount = store.artifacts.count
        let color: Color = artifactCount > 100 ? Bauhaus.Color.warning : Bauhaus.Color.success
        return ("\(artifactCount)", "artifacts stored", color)
    }

    private var policyBlocks: (value: String, trend: String, color: Color) {
        let blocked = store.jobs.filter { $0.status.uppercased() == "BLOCKED" }.count
        let color: Color = blocked == 0 ? Bauhaus.Color.success : Bauhaus.Color.warning
        return ("\(blocked)", blocked == 0 ? "All clear" : "Needs review", color)
    }

    // MARK: - Computed Alerts

    private var systemAlerts: [(severity: AlertRow.Severity, message: String, time: String)] {
        var alerts: [(AlertRow.Severity, String, String)] = []

        let failedJobs = store.jobs.filter { $0.status.uppercased() == "FAILED" }
        for job in failedJobs.prefix(3) {
            let timeAgo = job.createdAt.formatted(.relative(presentation: .named))
            alerts.append((.error, "Job '\(job.name)' failed", timeAgo))
        }

        let blockedJobs = store.jobs.filter { $0.status.uppercased() == "BLOCKED" }
        for job in blockedJobs.prefix(2) {
            let timeAgo = job.createdAt.formatted(.relative(presentation: .named))
            alerts.append((.warning, "Job '\(job.name)' blocked by policy", timeAgo))
        }

        if store.runningJobsCount > 5 {
            alerts.append((.info, "High job volume: \(store.runningJobsCount) jobs running", "now"))
        }

        if alerts.isEmpty {
            alerts.append((.info, "System operating normally", "now"))
        }

        return alerts
    }

    var body: some View {
        VStack(spacing: 0) {
            GovernanceStrip()

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x6) {

                    Text("System Status")
                        .font(Bauhaus.Font.header)
                        .padding(.horizontal, Bauhaus.Grid.x6)
                        .padding(.top, Bauhaus.Grid.x6)

                    // 1. Critical Metrics (now using real data)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 250))], spacing: Bauhaus.Grid.x4
                    ) {
                        MetricCard(
                            label: "Job Success Rate", value: jobSuccessRate.value, trend: jobSuccessRate.trend,
                            color: jobSuccessRate.color)
                        MetricCard(
                            label: "Running Jobs", value: activeWorkers.value, trend: activeWorkers.trend,
                            color: Bauhaus.Color.active)
                        MetricCard(
                            label: "Storage Usage", value: storageUsage.value, trend: storageUsage.trend,
                            color: storageUsage.color)
                        MetricCard(
                            label: "Policy Blocks", value: policyBlocks.value, trend: policyBlocks.trend,
                            color: policyBlocks.color)
                    }
                    .padding(.horizontal, Bauhaus.Grid.x6)

                    // 2. Policy Violations / Alerts (now using real data)
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                        Text("Recent Alerts")
                            .font(Bauhaus.Font.subHeader)

                        ForEach(Array(systemAlerts.enumerated()), id: \.offset) { _, alert in
                            AlertRow(
                                severity: alert.severity, message: alert.message,
                                time: alert.time)
                        }
                    }
                    .padding(.horizontal, Bauhaus.Grid.x6)

                    // 3. Active Workspaces
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                        Text("Active Workspaces")
                            .font(Bauhaus.Font.subHeader)

                        VStack(spacing: 0) {
                            ForEach(store.workspaces) { workspace in
                                UserRow(name: workspace.name, status: "Active")
                                if workspace.id != store.workspaces.last?.id {
                                    Divider()
                                }
                            }

                            if store.workspaces.isEmpty {
                                Text("No active workspaces")
                                    .font(Bauhaus.Font.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(Bauhaus.Grid.x3)
                            }
                        }
                        .background(Bauhaus.Color.cardBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Bauhaus.Color.border))
                    }
                    .padding(.horizontal, Bauhaus.Grid.x6)
                }
                .padding(.bottom, Bauhaus.Grid.x8)
            }
        }
    }
}

// MARK: - Components

struct MetricCard: View {
    let label: String
    let value: String
    let trend: String
    let color: SwiftUI.Color

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text(label.uppercased())
                .font(Bauhaus.Font.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 32, weight: .bold))

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text(trend)
            }
            .font(Bauhaus.Font.caption)
            .foregroundStyle(color)
        }
        .padding(Bauhaus.Grid.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bauhaus.Color.cardBackground)
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.radius).stroke(Bauhaus.Color.border))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue(trend)
    }
}

struct AlertRow: View {
    enum Severity { case info, warning, error }
    let severity: Severity
    let message: String
    let time: String

    var icon: String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    var severityLabel: String {
        switch severity {
        case .info: return "Information"
        case .warning: return "Warning"
        case .error: return "Critical Error"
        }
    }

    var color: SwiftUI.Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(message)
            Spacer()
            Text(time)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Bauhaus.Grid.x3)
        .background(color.opacity(0.05))
        .cornerRadius(4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severityLabel): \(message), \(time)")
    }
}

struct UserRow: View {
    let name: String
    let status: String

    var body: some View {
        HStack {
            Image(systemName: "person.circle")
            Text(name)
            Spacer()
            Text(status)
                .font(Bauhaus.Font.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(4)
        }
        .padding(Bauhaus.Grid.x3)
    }
}
