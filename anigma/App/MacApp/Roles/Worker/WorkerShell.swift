//
//  WorkerShell.swift
//  AnigmaAppMac
//
//  The "Production Line" for Workers.
//  Focus: Throughput, Queue Management, Review.
//  Structure: Governance Strip + Job Queue (Left) + Workbench (Right).
//

import AnigmaClientKit
import SwiftUI

struct WorkerShell: View {
    @Environment(AppStore.self) private var store
    @State private var selectedJobId: JobID?

    var body: some View {
        VStack(spacing: 0) {
            GovernanceStrip()

            NavigationSplitView {
                // Left: The Queue
                WorkerJobQueue(selectedJobId: $selectedJobId)
                    .navigationTitle("Global Queue")
            } detail: {
                // Right: The Workbench
                if let jobId = selectedJobId, let job = store.jobs.first(where: { $0.id == jobId }) {
                    WorkerWorkbench(job: job)
                } else {
                    ContentUnavailableView("No Job Selected", systemImage: "checklist")
                }
            }
        }
    }
}

// MARK: - Components

struct WorkerJobQueue: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedJobId: JobID?

    var body: some View {
        List(selection: $selectedJobId) {
            ForEach(store.jobs) { job in
                WorkerJobRow(job: job)
                    .tag(job.id)
            }
        }
        .listStyle(.plain)
    }
}

struct WorkerJobRow: View {
    let job: JobSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.name)
                    .font(Bauhaus.Font.subHeader)
                Spacer()
                Bauhaus.StatusChip(
                    label: job.status,
                    color: colorForStatus(job.status),
                    icon: nil
                )
                .accessibilityLabel("Status: \(job.status)")
            }
            .accessibilityElement(children: .combine)
            Text(job.id)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(.secondary)

            Text("Submitted: \(job.createdAt, format: .relative(presentation: .named))")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.name), Status: \(job.status), Submitted \(job.createdAt.formatted(.relative(presentation: .named)))")
        .accessibilityHint("Double click to open job details")
    }

    func colorForStatus(_ status: String) -> SwiftUI.Color {
        switch status.uppercased() {
        case "RUNNING": return Bauhaus.Color.queueRunning
        case "COMPLETED", "SUCCEEDED": return Bauhaus.Color.queueComplete
        case "FAILED": return Bauhaus.Color.error
        default: return Bauhaus.Color.queueQueued
        }
    }
}

struct WorkerWorkbench: View {
    let job: JobSummary
    @Environment(AppStore.self) private var store

    /// Extract action type from job name (assumes format like "OCR: filename" or just action name)
    private var actionType: String {
        if let colonIndex = job.name.firstIndex(of: ":") {
            return String(job.name[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        }
        return job.name
    }

    /// Get associated artifacts for this job (simplified heuristic)
    private var inputArtifacts: [AnigmaClientKit.ArtifactSummary] {
        // Try to find artifacts associated with this job
        // In a full implementation, jobs would have an inputArtifactIds field
        store.artifacts.filter { artifact in
            job.name.localizedCaseInsensitiveContains(artifact.name) ||
            artifact.name.localizedCaseInsensitiveContains(actionType)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {

            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Job #\(job.id.prefix(8))...")
                        .font(Bauhaus.Font.header)
                    Text("Action: \(actionType)")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Escalate", systemImage: "exclamationmark.triangle") { /* ... */   }
                    .buttonStyle(.bordered)
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.cardBackground)

            Divider()

            // Workspace
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {

                    // Inputs
                    Bauhaus.Card {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                            Text("INPUTS")
                                .font(Bauhaus.Font.subHeader)
                                .accessibilityAddTraits(.isHeader)

                            if inputArtifacts.isEmpty {
                                Text("No associated input artifacts")
                                    .font(Bauhaus.Font.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(Bauhaus.Grid.x2)
                            } else {
                                ForEach(inputArtifacts, id: \.id) { artifact in
                                    HStack {
                                        Image(systemName: iconForArtifact(artifact.name))
                                            .accessibilityHidden(true)
                                        Text(artifact.name)
                                    }
                                    .padding(Bauhaus.Grid.x2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                    .accessibilityLabel("Input file: \(artifact.name)")
                                }
                            }
                        }
                    }

                    // Process Controls
                    HStack(spacing: Bauhaus.Grid.x4) {
                        Button(action: {}) {
                            Label("Approve Output", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Bauhaus.Color.success)
                        .accessibilityHint("Approves the job and moves it to the next stage")

                        Button(action: {}) {
                            Label("Reject", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Bauhaus.Color.error)
                        .accessibilityHint("Rejects the job and returns it to queue")
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
        .background(Color(.textBackgroundColor))
    }

    private func iconForArtifact(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        case "mp4", "mov", "avi": return "video.fill"
        case "txt", "md": return "doc.text.fill"
        case "json", "xml", "yaml": return "curlybraces"
        default: return "doc.fill"
        }
    }
}
