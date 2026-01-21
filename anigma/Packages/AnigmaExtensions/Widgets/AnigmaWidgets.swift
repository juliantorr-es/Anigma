//
//  AnigmaWidgets.swift
//  AnigmaExtensions
//
//  The Widget Bundle and individual Widget definitions.
//  Uses AnigmaSystemSpine.WidgetDataProvider for data.
//

import WidgetKit
import SwiftUI
import AnigmaSystemSpine

@main
struct AnigmaWidgets: WidgetBundle {
    var body: some Widget {
        InboxCountWidget()
        ActiveJobsWidget()
        // NextDeadlineWidget()
    }
}

// MARK: - Inbox Count Widget

struct InboxCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxEntry {
        InboxEntry(date: Date(), count: 5, lastItemDate: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxEntry) -> Void) {
        let entry = InboxEntry(date: Date(), count: 5, lastItemDate: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxEntry>) -> Void) {
        Task { [completion] in
            let stats = await WidgetDataProvider.shared.getInboxStats()
            let entry = InboxEntry(date: Date(), count: stats.count, lastItemDate: stats.lastItemDate)

            // Refresh every 15 minutes or when app foregrounds
            guard let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) else {
                fatalError("Failed to unwrap nextUpdate")
            }
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            await MainActor.run { completion(timeline) }
        }
    }
}

struct InboxEntry: TimelineEntry {
    let date: Date
    let count: Int
    let lastItemDate: Date?
}

struct InboxCountWidgetEntryView: View {
    var entry: InboxCountProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "tray")
                Text("Inbox")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text("\(entry.count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color("AccentColor")) // Assuming asset catalog

            if let last = entry.lastItemDate {
                Text("Last: \(last.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color("WidgetBackground")
        }
    }
}

struct InboxCountWidget: Widget {
    let kind: String = "AnigmaInboxCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InboxCountProvider()) { entry in
            InboxCountWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Inbox Count")
        .description("Keep track of unprocessed items.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Active Jobs Widget

struct ActiveJobsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveJobsEntry {
        ActiveJobsEntry(date: Date(), runningCount: 2, tasks: [
            WidgetTaskSummary(id: UUID(), title: "OCR Processing", isDone: false),
            WidgetTaskSummary(id: UUID(), title: "Summarize PDF", isDone: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveJobsEntry) -> Void) {
        let entry = ActiveJobsEntry(date: Date(), runningCount: 0, tasks: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveJobsEntry>) -> Void) {
        Task { [completion] in
            let tasks = await WidgetDataProvider.shared.getTodayTasks()
            let entry = ActiveJobsEntry(date: Date(), runningCount: tasks.count, tasks: tasks)

            guard let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) else {
                fatalError("Failed to unwrap nextUpdate")
            }
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            await MainActor.run { completion(timeline) }
        }
    }
}

struct ActiveJobsEntry: TimelineEntry {
    let date: Date
    let runningCount: Int
    let tasks: [WidgetTaskSummary]
}

struct ActiveJobsWidgetEntryView: View {
    var entry: ActiveJobsProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                Text("Active Jobs")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            if entry.tasks.isEmpty {
                Text("No active jobs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.tasks.prefix(3), id: \.id) { task in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                if entry.tasks.count > 3 {
                    Text("+ \(entry.tasks.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color("WidgetBackground")
        }
    }
}

struct ActiveJobsWidget: Widget {
    let kind: String = "AnigmaActiveJobsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveJobsProvider()) { entry in
            ActiveJobsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Active Jobs")
        .description("Monitor running background jobs.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
