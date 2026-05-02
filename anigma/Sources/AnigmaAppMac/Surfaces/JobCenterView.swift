//
//  JobCenterView.swift
//  AnigmaAppMac
//
//  The "Engine Room" of the application.
//  Visualizes the execution spine: Jobs -> Artifacts.
//

import SwiftUI
import AnigmaClientKit

struct JobCenterView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JOB CENTER")
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .tracking(1)
                    Text("Execution Control")
                        .font(Bauhaus.Font.header)
                }

                Spacer()

                Button {
                    store.isJobCenterPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Bauhaus.Font.displayS)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Job Center")
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.surface)
            .overlay(alignment: .bottom) {
                Divider()
            }

            ScrollView {
                VStack(spacing: Bauhaus.Grid.x3) {

                    // Active Local Jobs
                    if !store.localJobs.isEmpty {
                        SectionHeader(title: "Local Processors", icon: "cpu")

                        ForEach(store.localJobs.reversed()) { job in
                            SpineJobRow(job: job)
                        }
                    }

                    // Daemon Jobs
                    if !store.jobs.isEmpty {
                        SectionHeader(title: "Daemon Tasks", icon: "server.rack")

                        ForEach(store.jobs) { job in
                            RemoteJobRow(job: job)
                        }
                    }

                    if store.localJobs.isEmpty && store.jobs.isEmpty {
                        EmptyState(icon: "sleep", message: "No active jobs.")
                            .padding(.top, Bauhaus.Grid.x5)
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
        .frame(width: 500, height: 600) // OK: Fixed panel size
        .background(Bauhaus.Color.background)
        .sheet(isPresented: Binding(
            get: { store.selectedReceiptJson != nil },
            set: { if !$0 { store.selectedReceiptJson = nil } }
        )) {
            ReceiptInspectorView()
        }
    }
}

private struct RemoteJobRow: View {
    let job: AnigmaClientKit.JobSummary
    @Environment(AppStore.self) private var store

    var statusColor: Color {
        switch job.status.lowercased() {
        case "running": return Bauhaus.Color.running
        case "completed", "success": return Bauhaus.Color.trusted
        case "failed", "error": return Bauhaus.Color.error
        default: return Bauhaus.Color.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Bauhaus.Grid.x2) {
            // Status Indicator
            if job.status.lowercased() == "running" {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: Bauhaus.Grid.x2 + 4, height: Bauhaus.Grid.x2 + 4)
            } else {
                Image(systemName: job.status.lowercased() == "completed" || job.status.lowercased() == "success" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(statusColor)
                    .font(Bauhaus.Font.headline)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(Bauhaus.Font.bodyBold)

                HStack {
                    Text(job.status.uppercased())
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(statusColor)

                    Text("•")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Text(job.createdAt.formatted(.relative(presentation: .named)))
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }

            Spacer()

            // Actions
            if let hash = job.finalReceiptHash {
                Button {
                    Task { await store.fetchReceipt(hash: hash) }
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("View CoreReceipt")
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Bauhaus.Color.accent)
            Text(title).font(Bauhaus.Font.subHeader)
            Spacer()
        }
        .padding(.bottom, Bauhaus.Grid.unit)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Bauhaus.Color.border).frame(height: 1) // OK: Divider height
        }
    }
}

private struct SpineJobRow: View {
    let job: AnigmaJob

    var statusColor: Color {
        switch job.status {
        case .running: return Bauhaus.Color.running
        case .completed: return Bauhaus.Color.trusted
        case .failed: return Bauhaus.Color.error
        case .pending: return Bauhaus.Color.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Bauhaus.Grid.x2) {
            // Status Indicator
            if job.status == .running {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: Bauhaus.Grid.x2 + 4, height: Bauhaus.Grid.x2 + 4)
            } else {
                Image(systemName: job.status == .completed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(statusColor)
                    .font(Bauhaus.Font.headline)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title)
                    .font(Bauhaus.Font.bodyBold)

                if let message = job.message {
                    Text(message)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                if job.status == .running {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                        .tint(Bauhaus.Color.accent)
                }

                HStack {
                    Text(job.status.rawValue.uppercased())
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(statusColor)

                    Text("•")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Text(job.startedAt.formatted(.relative(presentation: .named)))
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }

            Spacer()

            // Actions (if running)
            if job.status == .running {
                Button("Stop") { // tertiaryButtonStyle
                    // Hook up cancel
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Stop job: \(job.title)")
                .accessibilityHint("Cancels the running job")
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

private struct EmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: icon)
                .font(Bauhaus.Font.displayL)
                .foregroundStyle(Bauhaus.Color.border)
            Text(message)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
    }
}
