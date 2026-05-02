//
//  DownloadProgressView.swift
//  AnigmaAppMac
//
//  UI for displaying download progress with pause/resume/cancel.
//

import SwiftUI
import AnigmaCore
import ModelManagement

public struct DownloadProgressView: View {
    let download: DownloadQueueManager.ActiveDownload
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void

    public init(
        download: DownloadQueueManager.ActiveDownload,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.download = download
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.repo.split(separator: "/").last.map(String.init) ?? download.repo)
                        .font(.headline)
                    Text(download.file)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DownloadStatusBadge(state: download.state)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: download.progress.percentage)
                    .progressViewStyle(.linear)

                HStack {
                    Text(download.progress.formattedProgress)
                    Spacer()
                    Text("\(Int(download.progress.percentage * 100))%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Speed and ETA
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text(download.progress.formattedSpeed)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                if let eta = download.progress.estimatedSecondsRemaining {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("ETA: \(formatDuration(eta))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Duration
            HStack {
                Image(systemName: "timer")
                Text("Started \(formatDate(download.startedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Actions
            HStack(spacing: 12) {
                switch download.state {
                case .downloading:
                    Button(action: onPause) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)

                case .paused:
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .failed:
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                case .completed:
                    EmptyView()

                case .cancelled:
                    EmptyView()
                }

                Button(role: .destructive, action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .disabled(download.state.isCompleted)

                Spacer()
            }
        }
        .padding()
        .background(Bauhaus.Color.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DownloadStatusBadge: View {
    let state: DownloadState

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .downloading:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Downloading")
                    .font(.caption2)

            case .paused:
                Image(systemName: "pause.circle.fill")
                Text("Paused")
                    .font(.caption2)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Complete")
                    .font(.caption2)

            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Failed")
                    .font(.caption2)

            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Cancelled")
                    .font(.caption2)
            }
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(4)
    }

    private var statusColor: Color {
        switch state {
        case .downloading:
            return Bauhaus.Color.running
        case .paused:
            return .orange
        case .completed:
            return Bauhaus.Color.success
        case .failed:
            return Bauhaus.Color.error
        case .cancelled:
            return .orange
        }
    }
}

extension DownloadState {
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

public struct ActiveDownloadsView: View {
    @Environment(AppStore.self) private var appStore
    @State private var downloads: [DownloadQueueManager.ActiveDownload] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if downloads.isEmpty {
                ContentUnavailableView(
                    "No Active Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Downloads will appear here when you start them")
                )
            } else {
                HStack {
                    Text("\(downloads.count) active download\(downloads.count == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()
                    Button("Cancel All") {
                        Task {
                            if let queue = appStore.downloadQueue {
                                await queue.cancelAll()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(downloads, id: \.id) { download in
                    DownloadProgressView(
                        download: download,
                        onPause: { pause(download: download) },
                        onResume: { resume(download: download) },
                        onCancel: { cancel(download: download) },
                        onRetry: { retry(download: download) }
                    )
                }
            }
        }
        .padding()
        .task {
            await refreshDownloads()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await refreshDownloads()
            }
        }
    }

    private func refreshDownloads() async {
        if let queue = appStore.downloadQueue {
            let status = await queue.getQueueStatus()
            let all = await queue.getAllDownloads()
            await MainActor.run {
                self.downloads = status.activeCount > 0 ? all : []
            }
        }
    }

    private func pause(download: DownloadQueueManager.ActiveDownload) {
        Task {
            try? await appStore.downloadQueue?.pause(jobId: download.id)
        }
    }

    private func resume(download: DownloadQueueManager.ActiveDownload) {
        Task {
            try? await appStore.downloadQueue?.resume(jobId: download.id)
        }
    }

    private func cancel(download: DownloadQueueManager.ActiveDownload) {
        Task {
            try? await appStore.downloadQueue?.cancel(jobId: download.id)
        }
    }

    private func retry(download: DownloadQueueManager.ActiveDownload) {
        Task {
            try? await appStore.downloadQueue?.enqueue(
                repo: download.repo,
                file: download.file,
                priority: .high
            )
        }
    }
}
