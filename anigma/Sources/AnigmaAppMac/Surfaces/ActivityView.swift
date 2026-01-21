//
//  ActivityView.swift
//  AnigmaAppMac
//
//  Activity - job progress and history.
//  Bauhaus styling: visible table structure, minimal decoration.
//

import SwiftUI
import AnigmaClientKit

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Set<JobID> = []

    var body: some View {
        Group {
            if store.jobs.isEmpty {
                ActivityEmptyState()
            } else {
                ActivityContent(selection: $selection)
            }
        }
        .navigationTitle("Activity")
        .background(Bauhaus.Color.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Logic to refresh activity if needed
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityLabel("Refresh activity")
            }
        }
        .sheet(isPresented: Binding(
            get: { store.selectedReceiptJson != nil },
            set: { if !$0 { store.selectedReceiptJson = nil } }
        )) {
            ReceiptInspectorView()
        }
    }
}

struct ReceiptInspectorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    if let json = store.selectedReceiptJson {
                        Text(json)
                            .font(Bauhaus.Font.mono)
                            .padding()
                            .textSelection(.enabled)
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("Receipt Audit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() } // Toolbar ButtonStyle
                        .keyboardShortcut(.return, modifiers: [])
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let json = store.selectedReceiptJson {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                        }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - Empty State

struct ActivityEmptyState: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Table Header Structure
            HStack(spacing: 0) {
                ActivityHeader(title: "Status", width: 80)
                ActivityHeader(title: "Job", width: nil)
                ActivityHeader(title: "Evidence", width: 100)
                ActivityHeader(title: "Time", width: 100)
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()
            .accessibilityHidden(true) // Headers in empty state are decorative context

            VStack(spacing: Bauhaus.Grid.x4) {
                Spacer()
                Image(systemName: "clock.fill")
                    .font(Bauhaus.Font.displayXL)
                    .foregroundStyle(Bauhaus.Color.borderStrong)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("No activity recorded")
                        .font(Bauhaus.Font.header)
                        .accessibilityAddTraits(.isHeader)
                    Text("Actions performed will appear here with verification receipts.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Button("Connect Sources") { // Primary ButtonStyle
                        store.isSourceConnectionPresented = true
                    }
                    .primaryButtonStyle()
                    .padding(.top, 12)
                    .accessibilityLabel("Connect Sources")
                    .accessibilityHint("Opens the source connection dialog")
                    .keyboardShortcut("k", modifiers: .command)
                }
                Spacer()
            }
        }
    }
}

struct ActivityHeader: View {
    let title: String
    let width: CGFloat?

    var body: some View {
        Text(title.uppercased())
            .font(Bauhaus.Font.caption)
            .fontWeight(.bold)
            .foregroundStyle(Bauhaus.Color.textSecondary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, 8)
    }
}

// MARK: - Content

struct ActivityContent: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: Set<JobID>

    var body: some View {
        List {
            // Failed Jobs Section (LOUD)
            let failedJobs = store.localJobs.filter { $0.status == .failed }
            if !failedJobs.isEmpty {
                Section {
                    ForEach(failedJobs) { job in
                        FailedJobRow(job: job)
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Bauhaus.Color.error)
                        Text("FAILED JOBS")
                            .foregroundStyle(Bauhaus.Color.error)
                            .fontWeight(.bold)
                    }
                }
                .listRowBackground(Bauhaus.Color.error.opacity(0.1))
            }

            // Active Local Jobs Section
            let activeLocal = store.localJobs.filter { $0.status == .running || $0.status == .pending }
            if !activeLocal.isEmpty {
                Section("Active Pipeline") {
                    ForEach(activeLocal) { job in
                        ActivityJobRow(job: job)
                    }
                }
            }

            // Recent History Section (only completed, not failed)
            Section("Recent History") {
                // Completed Local Jobs
                ForEach(store.localJobs.filter { $0.status == .completed }.reversed()) { job in
                    ActivityJobRow(job: job)
                }

                // Remote Jobs (Daemon)
                ForEach(store.jobs) { job in
                    RemoteActivityRow(job: job)
                }

                if store.localJobs.isEmpty && store.jobs.isEmpty {
                    Text("No history available.").font(Bauhaus.Font.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

private struct FailedJobRow: View {
    let job: AnigmaJob
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(Bauhaus.Color.error)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(Bauhaus.Font.body)
                        .fontWeight(.semibold)

                    if let message = job.message {
                        Text(message)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.error.opacity(0.8))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(job.startedAt, style: .relative)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let daemonId = job.daemonJobId {
                    Button("Retry") { // ButtonStyle
                        Task {
                            // Resubmit - for now just show toast
                            store.showError("Retry not yet implemented for: \(daemonId)")
                        }
                    }
                    .accessibilityLabel("Retry \(job.title)")
                    .buttonStyle(.borderedProminent)
                    .tint(Bauhaus.Color.error)
                    .controlSize(.small)
                }

                Button("Dismiss") { // ButtonStyle
                    if let index = store.localJobs.firstIndex(where: { $0.id == job.id }) {
                        store.localJobs.remove(at: index)
                    }
                }
                .accessibilityLabel("Dismiss failure notification")
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let hash = job.receiptHash {
                    Button("View Error Receipt") { // ButtonStyle
                        Task { await store.fetchReceipt(hash: hash) }
                    }
                    .accessibilityLabel("View failure receipt")
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ActivityJobRow: View {
    let job: AnigmaJob
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.title).font(Bauhaus.Font.bodyBold)
                    Spacer()
                    Text(job.startedAt, style: .time).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                }

                if let msg = job.message {
                    Text(msg)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                if job.status == .running {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                        .tint(Bauhaus.Color.accent)
                        .frame(maxWidth: 200)
                }

                HStack(spacing: 8) {
                    JobStatusBadge(status: job.status.rawValue)

                    if let hash = job.receiptHash {
                        Button {
                            Task { await store.fetchReceipt(hash: hash) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Bauhaus.Color.accent)
                                Text(hash.prefix(8) + "…").font(Bauhaus.Font.mono).foregroundStyle(Bauhaus.Color.accent)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Bauhaus.Color.accent.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("View Audit Receipt")
                    } else if job.status == .completed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Bauhaus.Color.accent)
                            Text("Verified").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.accent)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RemoteActivityRow: View {
    let job: JobSummary
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.name).font(Bauhaus.Font.body)
                    Spacer()
                    Text(job.createdAt, style: .time).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                }

                HStack(spacing: 8) {
                    JobStatusBadge(status: job.status)

                    if let hash = job.finalReceiptHash {
                        Button {
                            Task { await store.fetchReceipt(hash: hash) }
                        } label: {
                            Text(hash.prefix(8) + "…")
                                .font(Bauhaus.Font.mono)
                                .foregroundStyle(Bauhaus.Color.accent)
                                .padding(.horizontal, 4)
                                .background(Bauhaus.Color.accent.opacity(0.1))
                                .cornerRadius(2)
                        }
                        .buttonStyle(.plain)
                        .help("View Audit Receipt")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
