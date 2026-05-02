import SwiftUI

struct JobCenterPanel: View {
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
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Picker("Filter", selection: $filter) {
                    ForEach(JobFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Stream
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredJobs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 32))
                                .foregroundStyle(Bauhaus.Color.textTertiary)
                            Text("No jobs found.")
                                .font(Bauhaus.Font.body)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
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
                // appState.selectedSurface = .activity // If we had binding to AppStore or if AppState controlled navigation
            } label: {
                HStack {
                    Text("View Full Ledger").font(Bauhaus.Font.caption)
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 10))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Bauhaus.Color.accent)
        }
        .frame(width: 350) // Increased width
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

struct JobCenterRow: View {
    let job: AppState.JobEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .frame(height: 2)
                            .padding(.top, 4)
                    }

                    if let _ = job.receiptLink {
                        Button("View Receipt") {
                            // Open receipt
                        }
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.accent)
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                Spacer()

                // Menu
                Menu {
                    Button("Cancel", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }

            if job.status == .blocked {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Bauhaus.Color.warning)
                    Text("Permission required")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Spacer()
                    Button("Resolve") {
                        // Resolve action
                    }
                    .font(Bauhaus.Font.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(4)
                }
                .padding(6)
                .background(Bauhaus.Color.warning.opacity(0.05))
                .cornerRadius(4)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .overlay(
            Rectangle()
                .fill(Bauhaus.Color.border.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
