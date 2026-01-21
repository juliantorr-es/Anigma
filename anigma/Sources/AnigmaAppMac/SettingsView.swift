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
        @Bindable var bindableStore = store
        let googleConnected = store.isGoogleLinked
        let googleConfigured = !store.googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let googleRefreshText = store.googleOAuthLastRefreshAt?.formatted(
            date: .abbreviated,
            time: .shortened
        )

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
                    Text(googleConnected ? "Linked" : "Not linked")
                        .foregroundStyle(googleConnected ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Google Drive: \(googleConnected ? "Linked" : "Not linked")")
                .accessibilityAddTraits(.isStaticText)

                TextField("Google OAuth Client ID", text: $bindableStore.googleOAuthClientId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Google OAuth Client ID")
                    .accessibilityHint("Required to connect Google Drive.")

                if !googleConfigured {
                    Text("Required to connect Google Drive.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .accessibilityHidden(true)
                }

                if googleConnected {
                    if let googleRefreshText {
                        Text("Last refreshed: \(googleRefreshText)")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                            .accessibilityLabel("Google token last refreshed \(googleRefreshText)")
                    }

                    Button("Refresh Google Token") {
                        Task { await store.refreshGoogleOAuthTokenIfNeeded(force: true, displayToast: true) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Refresh Google Token")

                    Button("Disconnect Google Drive") {
                        store.disconnectGoogle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Disconnect Google Drive")
                }

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

                Section("Harmonia CLI") {
                    DaemonStatusView()
                        .environment(store)

                    Divider()

                    VaultInspectorView()
                        .environment(store)

                    Divider()

                    PipelineMonitorView()
                        .environment(store)

                    Divider()

                    TechDebtDashboardView()
                        .environment(store)

                    Divider()

                    HarmoniaSearchView()
                        .environment(store)

                    Divider()

                    HarmoniaBackgroundSyncSettingsView()
                        .environment(store)

                    Divider()

                    HarmoniaCommandHistoryView()
                        .environment(store)
                }

                Section("Doctrine System") {
                    DoctrineScannerView()
                        .environment(store)

                    Divider()

                    DoctrineViolationsDashboardView()
                        .environment(store)

                    Divider()

                    DoctrinePackManagerView()
                        .environment(store)
                }

                Section("ML Worker") {
                    MLWorkerStatusView()
                        .environment(store)

                    Divider()

                    MLWorkerTaskSubmissionView()
                        .environment(store)

                    Divider()

                    MLWorkerTaskMonitorView()
                        .environment(store)
                }

                Section("Model Registry") {
                    ModelRegistryView()
                        .environment(store)
                }

                Section("Access Control") {
                    AccessControlView()
                        .environment(store)
                }

                Section("Surface Manager") {
                    SurfaceManagerView()
                        .environment(store)
                }

                Section("Code Analysis") {
                    CodeAnalysisView()
                        .environment(store)
                }

                Section("Pipeline Manager") {
                    PipelineManagerView()
                        .environment(store)
                }

                Section("Document Generation") {
                    DocumentGenerationView()
                        .environment(store)
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
