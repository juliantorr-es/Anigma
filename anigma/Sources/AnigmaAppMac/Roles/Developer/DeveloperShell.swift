//
//  DeveloperShell.swift
//  AnigmaAppMac
//
//  The "Instrumentation Lab" for Developers.
//  Focus: Internals, Raw Data, Debugging.
//  Structure: Governance Strip + Tabbed Diagnostic Views.
//

import SwiftUI

struct DeveloperShell: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: DevTab = .logs

    enum DevTab {
        case logs, state, network
    }

    var body: some View {
        VStack(spacing: 0) {
            GovernanceStrip()

            VStack(spacing: 0) {
                // Dev Toolbar
                HStack(spacing: Bauhaus.Grid.x4) {
                    Picker("Tool", selection: $selectedTab) {
                        Text("System Logs").tag(DevTab.logs)
                        Text("App State").tag(DevTab.state)
                        Text("Network Traces").tag(DevTab.network)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)

                    Spacer()

                    Button("Flush Cache", systemImage: "trash") { /* ... */   }
                    Button("Restart Daemon", systemImage: "arrow.clockwise") { /* ... */   }
                }
                .padding(Bauhaus.Grid.x3)
                .background(Bauhaus.Color.cardBackground)
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(Bauhaus.Color.border),
                    alignment: .bottom)

                // Content
                switch selectedTab {
                case .logs:
                    ConsoleLogView()
                case .state:
                    StateDumpView()
                case .network:
                    NetworkTraceView()
                }
            }
        }
    }
}

struct ConsoleLogView: View {
    var body: some View {
        List {
            Text("12:42:01 [INFO] Daemon started on port 8080").font(Bauhaus.Font.mono)
            Text("12:42:02 [DEBUG] Loading plugins...").font(Bauhaus.Font.mono)
            Text("12:42:02 [INFO] Loaded 4 capabilities").font(Bauhaus.Font.mono)
            Text("12:42:05 [WARN] Connection slow (latency: 120ms)").font(Bauhaus.Font.mono)
                .foregroundStyle(.orange)
        }
        .listStyle(.plain)
    }
}

struct StateDumpView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section("Global") {
                LabeledContent("Current Role", value: store.role.rawValue)
                LabeledContent("Governance", value: store.governanceMode.rawValue)
                LabeledContent("Online", value: String(store.isOnline))
            }

            Section("Workspaces") {
                ForEach(store.workspaces) { ws in
                    Text("\(ws.name) (\(ws.id))").font(Bauhaus.Font.mono)
                }
            }

            Section("Jobs") {
                ForEach(store.jobs) { job in
                    Text("\(job.id): \(job.status)").font(Bauhaus.Font.mono)
                }
            }
        }
    }
}

struct NetworkTraceView: View {
    var body: some View {
        VStack {
            Text("Network Traffic (Real-time)")
                .font(Bauhaus.Font.header)
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No active requests.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
