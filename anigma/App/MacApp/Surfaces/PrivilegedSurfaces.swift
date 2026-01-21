//
//  PrivilegedSurfaces.swift
//  AnigmaAppMac
//
//  Worker, Admin, Developer surfaces.
//

import SwiftUI

struct WorkerQueueView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationSplitView {
            List {
                Text("\(store.jobs.count) jobs in queue")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Worker Queue")
        } detail: {
            ContentUnavailableView(
                "Select a job",
                systemImage: "doc.text",
                description: Text("Review and process jobs.")
            )
        }
    }
}

struct AdminConsoleView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Policies", systemImage: "doc.badge.gearshape")
                Label("Audit Log", systemImage: "list.bullet.clipboard")
                Label("System Health", systemImage: "heart.text.square")
            }
            .navigationTitle("Admin Console")
        } detail: {
            ContentUnavailableView(
                "Select a section",
                systemImage: "gearshape",
                description: Text("Manage system configuration.")
            )
        }
    }
}

struct DevConsoleView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationSplitView {
            List {
                Label("Traces", systemImage: "waveform.path")
                Label("Receipts", systemImage: "doc.text")
                Label("Rerun", systemImage: "arrow.counterclockwise")
            }
            .navigationTitle("Dev Console")
        } detail: {
            ContentUnavailableView(
                "Debug tools",
                systemImage: "terminal",
                description: Text("Traces, receipts, deterministic replay.")
            )
        }
    }
}
