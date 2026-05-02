//
//  JobListView.swift
//  AnigmaAppMac
//
//  List of jobs in the current workspace with real-time status updates.
//

import AnigmaClientKit
import SwiftUI

struct JobListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        let jobs: [AnigmaClientKit.JobSummary] = store.filteredJobs
        return VStack(spacing: 0) {
            if jobs.isEmpty {
                ContentUnavailableView {
                    Label("No Jobs", systemImage: "gearshape.2")
                } description: {
                    Text("Submit a job to see it here")
                } actions: {
                    Button("Submit Test Job") {
                        Task {
                            await store.submitJob(
                                action: "echo",
                                parameters: ["message": .string("Hello from macOS client!")]
                            )
                        }
                    }
                }
            } else {
                List(jobs, id: \.id) { job in
                    JobRow(job: job)
                }
            }
        }
        .searchable(text: $bindableStore.jobSearchQuery, prompt: "Search jobs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EmptyView()
            }
        }
    }
}

struct JobRow: View {
    let job: AnigmaClientKit.JobSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name)
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textPrimary)

                HStack(spacing: 8) {
                    JobStatusBadge(status: job.status)

                    if job.isTrusted {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(Bauhaus.Color.success)
                            .font(.caption2)
                            .accessibilityLabel("Verified Truth")
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = inside
            }
        }
        .background(isHovered ? Bauhaus.Color.textPrimary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.name), \(job.status)\(job.isTrusted ? ", Verified" : "")")
        .accessibilityHint("Double tap to view details")
    }

    @State private var isHovered = false
}
