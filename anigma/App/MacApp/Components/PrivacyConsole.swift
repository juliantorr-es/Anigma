//
//  PrivacyConsole.swift
//  AnigmaAppMac
//
//  Central dashboard for privacy settings and network transparency.
//  Enforces the "Local First" promise by making cloud access explicit.
//

import SwiftUI

struct PrivacyConsole: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(Bauhaus.Font.header)
                Text("Privacy & Trust")
                    .font(Bauhaus.Font.header)
                Spacer()
            }
            .padding(Bauhaus.Grid.x6)
            .background(Bauhaus.Color.background.opacity(0.5))

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x6) {

                    // 1. Critical Switch: On-Device vs Cloud
                    PrivacyCard(
                        title: "Data Processing",
                        icon: "server.rack",
                        status: store.privacySettings.allowCloudAI ? "HYBRID" : "LOCAL ONLY",
                        statusColor: store.privacySettings.allowCloudAI
                            ? Bauhaus.Color.warning : Bauhaus.Color.success
                    ) {
                        Toggle(isOn: $bindableStore.privacySettings.allowCloudAI) {
                            VStack(alignment: .leading) {
                                Text("Allow Third-Party Cloud AI")
                                    .font(Bauhaus.Font.subHeader)
                                Text(
                                    "If enabled, some data may be sent to approved cloud providers (e.g. OpenAI) for advanced processing. If disabled, all data stays on this device."
                                )
                                .font(Bauhaus.Font.body)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, Bauhaus.Grid.x2)
                    }

                    // 2. Audit Summary
                    PrivacyCard(
                        title: "Network Activity",
                        icon: "network",
                        status: store.isOnline ? "CONNECTED" : "OFFLINE",
                        statusColor: store.isOnline
                            ? Bauhaus.Color.active : Bauhaus.Color.governanceReadOnly
                    ) {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                            Text("Recent outbound requests:")
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(.secondary)

                            if store.networkActivityLog.isEmpty {
                                Text("No recent network activity")
                                    .font(Bauhaus.Font.mono)
                                    .foregroundStyle(.secondary)
                                    .padding(Bauhaus.Grid.x2)
                            } else {
                                ForEach(store.networkActivityLog.suffix(5)) { entry in
                                    HStack {
                                        Text(entry.domain)
                                            .font(Bauhaus.Font.mono)
                                        Spacer()
                                        Text(entry.isAllowed ? "ALLOWED" : "BLOCKED")
                                            .font(Bauhaus.Font.monoBold)
                                            .foregroundStyle(entry.isAllowed ? Bauhaus.Color.success : Bauhaus.Color.error)
                                    }
                                    .padding(Bauhaus.Grid.x2)
                                    .background(Color.black.opacity(0.05))
                                    .cornerRadius(4)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Request to \(entry.domain): \(entry.isAllowed ? "Allowed" : "Blocked")")
                                }
                            }
                        }
                    }

                    // 3. Telemetry
                    PrivacyCard(
                        title: "App Analytics",
                        icon: "chart.bar",
                        status: "MINIMAL",
                        statusColor: Bauhaus.Color.active
                    ) {
                        Toggle(
                            "Share Crash Reports", isOn: $bindableStore.privacySettings.allowCrashReports)
                        Toggle("Share Anonymous Usage", isOn: $bindableStore.privacySettings.allowAnalytics)
                    }
                }
                .padding(Bauhaus.Grid.x6)
            }
        }
        .frame(width: 500, height: 600)
        .background(Bauhaus.Color.cardBackground)
    }
}

// Helper Card
struct PrivacyCard<Content: View>: View {
    let title: String
    let icon: String
    let status: String
    let statusColor: SwiftUI.Color
    let content: Content

    init(
        title: String, icon: String, status: String, statusColor: SwiftUI.Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.status = status
        self.statusColor = statusColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            HStack {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Bauhaus.Font.subHeader)
                Spacer()
                Bauhaus.StatusChip(label: status, color: statusColor, icon: nil)
                    .accessibilityLabel("Status: \(status)")
            }
            .accessibilityElement(children: .combine)

            Divider()

            content
        }
        .padding(Bauhaus.Grid.x4)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}
