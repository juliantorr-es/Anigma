import SwiftUI

// NonPersistent
struct JobCenterPanel: View, Sendable {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var filter: JobFilter = .all

    enum JobFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case blocked = "Blocked"
        case attention = "Attention"
    }

    var filteredJobs: [AppState.JobEntry] {
        switch filter {
        case .all: return appState.jobStream
        case .running: return appState.jobStream.filter { $0.status == .running }
        case .blocked: return appState.jobStream.filter { $0.status == .blocked }
        case .attention: return appState.jobStream.filter { $0.status == .attention }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Bauhaus.Grid.unit) {
                HStack {
                    Text("Job Center")
                        .font(Bauhaus.Font.header)
                    Spacer()
                    if appState.runningJobsCount > 0 {
                        Text("\(appState.runningJobsCount) Running")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.running)
                    }

                    // Close Button (for popover context)
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close job center")
                }

                Picker("Filter", selection: $filter) {
                    ForEach(JobFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Filter jobs")
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Stream
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredJobs.isEmpty {
                        VStack(spacing: Bauhaus.Grid.x2) {
                            Image(systemName: "circle.dotted")
                                .font(Bauhaus.Font.displayM)
                                .foregroundStyle(Bauhaus.Color.textTertiary)
                            Text("No jobs found.")
                                .font(Bauhaus.Font.body)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Bauhaus.Grid.x5)
                    } else {
                        ForEach(filteredJobs) { job in
                            JobCenterRow(job: job)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            Button {
                // Navigate to Activity
            } label: {
                HStack {
                    Text("View Full Ledger").font(Bauhaus.Font.caption)
                    Spacer()
                    Image(systemName: "arrow.right").font(Bauhaus.Font.small)
                }
                .padding(.horizontal, Bauhaus.Grid.x2)
                .padding(.vertical, Bauhaus.Grid.unit + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Bauhaus.Color.accent)
            .accessibilityLabel("View full job ledger")
            .accessibilityHint("Opens activity view to see complete job history")
        }
        .frame(width: 350) // OK: Fixed popover width
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

// NonPersistent
struct JobCenterRow: View, Sendable {
    let job: AppState.JobEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack(alignment: .top, spacing: Bauhaus.Grid.unit) {
                Bauhaus.StatusDot(state: job.status)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(Bauhaus.Font.subHeader)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    HStack {
                        Text(job.source)
                        Text("·")
                        Text(job.timestamp, style: .time)
                    }
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                    if let progress = job.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(height: 2) // OK: Fine progress lines
                            .padding(.top, 4)
                    }

                    if let _ = job.receiptLink {
                        Button("View CoreReceipt") {
                            // Open receipt
                        }
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.accent)
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                        .accessibilityLabel("View receipt for \(job.title)")
                    }
                }
                Spacer()

                // Menu
                Menu {
                    Button("Cancel", role: .destructive) { }
                        .accessibilityLabel("Cancel job: \(job.title)")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }

            if job.status == .blocked {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Bauhaus.Font.small)
                        .foregroundStyle(Bauhaus.Color.warning)
                    Text("Permission required")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Spacer()
                    Button("Resolve") {
                        // Resolve action
                    }
                    .accessibilityLabel("Resolve permission request")
                    .accessibilityHint("Grants the requested permission to unblock the job")
                    .font(Bauhaus.Font.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(2)
                }
                .padding(Bauhaus.Grid.unit / 2)
                .background(Bauhaus.Color.warning.opacity(0.05))
                .cornerRadius(2)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .overlay(
            Rectangle()
                .fill(Bauhaus.Color.border.opacity(0.5))
                .frame(height: 1), // OK: Divider line
            alignment: .bottom
        )
    }
}
