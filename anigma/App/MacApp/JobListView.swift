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
    @State private var selection: Set<AnigmaClientKit.JobID> = []

    var body: some View {
        @Bindable var bindableStore = store

        VStack(spacing: 0) {
            if store.jobs.isEmpty {
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
                List(store.filteredJobs, selection: $selection) { job in
                    JobRow(job: job)
                        .tag(job.id)
                        .onAppear {
                            if job.id == store.filteredJobs.last?.id && store.hasMoreJobs {
                                Task { await store.loadMoreJobs() }
                            }
                        }
                }

                // Action bar
                HStack {
                    Button("Submit Test Job") {
                        Task {
                            await store.submitJob(
                                action: "echo",
                                parameters: ["message": .string("Test job at \(Date())")]
                            )
                        }
                    }

                    Spacer()

                    Text("\(store.filteredJobs.count) jobs")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(.background.secondary)
            }
        }
        .onChange(of: selection) { _, newSelection in
            if newSelection.count == 1, let id = newSelection.first {
                store.inspectorSelection = .job(id: id)
            } else if newSelection.isEmpty {
                store.inspectorSelection = nil
            }
        }
        .searchable(text: $bindableStore.jobSearchQuery, prompt: "Search jobs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    if !selection.isEmpty {
                        Menu {
                            Button("Cancel Selected") {
                                Task {
                                    for id in selection {
                                        await store.cancelJob(id: id)
                                    }
                                }
                            }

                            Button("Delete Selected", role: .destructive) {
                                Task {
                                    for id in selection {
                                        await store.deleteJob(id: id)
                                    }
                                    selection.removeAll()
                                }
                            }
                        } label: {
                            Label("Bulk Actions", systemImage: "ellipsis.circle")
                        }
                    }

                    Menu {
                        Picker("Status", selection: $bindableStore.jobStatusFilter) {
                            ForEach(JobStatusFilter.allCases) { filter in
                                Text(filter.displayName).tag(filter)
                            }
                        }

                        Picker("Trust", selection: $bindableStore.jobTrustFilter) {
                            ForEach(JobTrustFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .symbolVariant(
                                (store.jobStatusFilter != .all || store.jobTrustFilter != .all)
                                    ? .fill : .none)
                    }
                }
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
