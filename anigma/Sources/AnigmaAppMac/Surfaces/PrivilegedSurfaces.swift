//
//  PrivilegedSurfaces.swift
//  AnigmaAppMac
//
//  Worker, Admin, Developer surfaces.
//

import SwiftUI

struct WorkerQueueView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedJobId: String?

    var body: some View {
        NavigationSplitView {
            List(store.jobs, selection: $selectedJobId) { job in
                VStack(alignment: .leading) {
                    Text(job.name).font(Bauhaus.Font.bodyBold)
                    HStack {
                        Text(job.id.prefix(8)).font(Bauhaus.Font.mono)
                        Spacer()
                        JobStatusBadge(status: job.status)
                    }
                }
                .tag(job.id)
            }
            .navigationTitle("Worker Queue")
        } detail: {
            if let id = selectedJobId {
                JobInspector(jobId: id)
            } else {
                ContentUnavailableView(
                    "Select a job",
                    systemImage: "checklist",
                    description: Text("Review and process jobs from the global queue.")
                )
            }
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
