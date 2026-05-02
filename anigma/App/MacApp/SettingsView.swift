//
//  SettingsView.swift
//  AnigmaAppMac
//
//  Settings - privacy and system control.
//  Bauhaus identity: intentional disclosure, no technical jargon upfront.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section("Identity & Privacy") {
                LabeledContent("Public Key", value: "ed25519:6f3a...1d2c")
                    .accessibilityLabel("Public Key: ed25519:6f3a...1d2c")
                LabeledContent("Local Storage", value: "420 MB used")
                    .accessibilityLabel("Local Storage Usage: 420 MB")
                Button("Export Personal Archive…") {}
                Button("Purge Local Cache") {}
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Purge Local Cache")
                    .accessibilityHint("Permanently deletes all locally cached data.")
            }

            Section("Connected Accounts") {
                HStack {
                    Label("Google Drive", systemImage: "link")
                    Spacer()
                    Text("Linked").foregroundStyle(Bauhaus.Color.accent)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Google Drive: Linked")
                .accessibilityAddTraits(.isStaticText)

                HStack {
                    Label("Canvas LMS", systemImage: "link")
                    Spacer()
                    Button("Connect") {}.buttonStyle(.bordered)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Canvas LMS: Not Connected")
            }

            // Advanced section - only shown in Build mode or behind disclosure
            if store.mode == .build {
                Section("System (Build Mode)") {
                    NavigationLink("Daemon Hosts") {
                        DaemonHostsList()
                    }
                    NavigationLink("Contract Governance") {
                        Text("Governance policy: Local First")
                    }
                }
            } else {
                DisclosureGroup("Advanced") {
                    NavigationLink("System Status") {
                        DaemonHostsList()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

struct DaemonHostsList: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            ForEach(store.hosts) { host in
                HStack {
                    VStack(alignment: .leading) {
                        Text(host.name).font(Bauhaus.Font.body)
                        Text(host.url.absoluteString).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                    Spacer()
                    JobStatusBadge(status: host.status.rawValue)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(host.name), \(host.status.rawValue)")
                .accessibilityHint("Host at \(host.url.absoluteString)")
            }
        }
        .navigationTitle("Daemon Hosts")
    }
}

#Preview {
    SettingsView()
        .frame(width: 400, height: 500)
}
