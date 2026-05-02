//
//  MLWorkerTaskMonitorView.swift
//  AnigmaAppMac
//
//  Monitor active and completed ML worker tasks.
//

import SwiftUI
import AnigmaHostMac
import MLWorkerCommon

// NonPersistent
struct MLWorkerTaskMonitorView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var selectedTask: MLWorkerClient.TaskStatusResponse?
    @State private var showCompletedOnly = false

    var filteredTasks: [MLWorkerClient.TaskStatusResponse] {
        if showCompletedOnly {
            return store.mlWorkerTasks.filter { $0.status == "completed" }
        }
        return store.mlWorkerTasks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            controlsView

            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                tasksListView
            }

            if let task = selectedTask {
                Divider()
                taskDetailView(task)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "list.bullet.clipboard")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Task Monitor")
                .font(Bauhaus.Font.header)

            Spacer()

            Text("\(filteredTasks.count) tasks")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }

    private var controlsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Toggle(isOn: $showCompletedOnly) {
                Text("Show Completed Only")
                    .font(Bauhaus.Font.caption)
            }
            .accessibilityLabel("Filter completed")
            .toggleStyle(.checkbox)

            Spacer()

            if !store.mlWorkerTasks.isEmpty {
                Button(action: { store.clearCompletedMLTasks() }) {
                    Label("Clear Completed", systemImage: "trash")
                        .font(Bauhaus.Font.caption)
                }
                .accessibilityLabel("Clear task history")
                .secondaryButtonStyle()
            }
        }
    }

    private var tasksListView: some View {
        ScrollView {
            LazyVStack(spacing: Bauhaus.Grid.x2) {
                ForEach(filteredTasks) { task in
                    taskRow(task)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTask = task
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("View details for \(task.task)")
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func taskRow(_ task: MLWorkerClient.TaskStatusResponse) -> some View {
        let isSelected = selectedTask?.id == task.id

        return HStack(spacing: Bauhaus.Grid.x2) {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                HStack {
                    statusIndicator(task.status)

                    Text(task.task)
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    Spacer()

                    Text(task.engine)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .frame(width: 16)

                    Text(task.createdAt, style: .relative)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    if let completed = task.completedAt {
                        Text("•")
                            .foregroundStyle(Bauhaus.Color.textTertiary)

                        Text("Completed \(completed, style: .relative)")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(Bauhaus.Grid.x2)
        .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                .stroke(isSelected ? Bauhaus.Color.accent : Color.clear, lineWidth: 1)
        )
    }

    private func statusIndicator(_ status: String) -> some View {
        let (color, icon): (Color, String) = {
            switch status.lowercased() {
            case "completed":
                return (Bauhaus.Color.success, "checkmark.circle.fill")
            case "processing":
                return (Bauhaus.Color.running, "arrow.triangle.2.circlepath")
            case "queued":
                return (Bauhaus.Color.warning, "clock.fill")
            case "failed":
                return (Bauhaus.Color.error, "xmark.circle.fill")
            default:
                return (Bauhaus.Color.textSecondary, "circle.fill")
            }
        }()

        return HStack(spacing: Bauhaus.Grid.unit) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(status.capitalized)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(color)
        }
    }

    private func taskDetailView(_ task: MLWorkerClient.TaskStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Task Details")
                .font(Bauhaus.Font.subHeader)

            detailRow(label: "Request ID", value: task.requestId)
            detailRow(label: "Engine", value: task.engine)
            detailRow(label: "Task Type", value: task.task)
            detailRow(label: "Status", value: task.status)
            detailRow(label: "Created", value: task.createdAt.formatted())

            if let completed = task.completedAt {
                detailRow(label: "Completed", value: completed.formatted())
            }

            if let metrics = task.metrics {
                Divider()
                metricsView(metrics)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func metricsView(_ metrics: MLWorkerCommon.MLWorkerMetrics) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("Metrics")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            if let tps = metrics.tokensPerSecond {
                metricRow(label: "Tokens/sec", value: String(format: "%.2f", tps))
            }

            if let total = metrics.totalTokens {
                metricRow(label: "Total Tokens", value: "\(total)")
            }

            if let duration = metrics.durationMs {
                metricRow(label: "Duration", value: "\(duration) ms")
            }

            if let memory = metrics.memoryBytes {
                let mb = Double(memory) / 1_000_000
                metricRow(label: "Memory", value: String(format: "%.2f MB", mb))
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Spacer()

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.accent)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No ML tasks")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("Submit tasks to see them here")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }
}
