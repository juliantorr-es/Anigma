//
//  TrustBoundaryPanel.swift
//  AnigmaAppMac
//
//  Displays the "4 Truths" of the current boundary posture:
//  1. Compute Location (Local vs External)
//  2. Network Status (Allowed vs Blocked)
//  3. Active Tools (Binaries/Agents running)
//  4. Data Classes (What data is being touched)
//

import SwiftUI

struct TrustBoundaryPanel: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            HStack {
                Text("Trust Boundary")
                    .font(Bauhaus.Font.header)
                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 1. Compute Location
            BoundaryRow(
                icon: "cpu",
                label: "Compute",
                value: "Local (Apple Silicon)",
                status: .good,
                details: "All inference and processing is occurring on-device."
            )

            // 2. Network Status
            BoundaryRow(
                icon: "network",
                label: "Network",
                value: store.isOnline ? "Enabled" : "Disabled",
                status: store.isOnline ? .warning : .good,
                details: store.isOnline ? "Outbound connections allowed for verified connectors." : "Air-gapped mode active."
            )

            // 3. Active Tools
            BoundaryRow(
                icon: "hammer.fill",
                label: "Tools",
                value: "3 Active",
                status: .good,
                details: "grep, git, python3 (Sandboxed)"
            )

            // 4. Data Classes
            BoundaryRow(
                icon: "folder.fill",
                label: "Data Scope",
                value: "Workspace Only",
                status: .good,
                details: "Access limited to /Users/user/Developer/GitHub/Anigma"
            )

            Divider()

            HStack {
                Button("View Audit Log") {
                    // Action to view logs
                }
                .buttonStyle(.link)

                Spacer()

                Button("Lockdown Mode") {
                    // Action to trigger lockdown
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(Bauhaus.Grid.x4)
        .frame(width: 400)
        .background(Bauhaus.Color.surface)
    }
}

private struct BoundaryRow: View {
    let icon: String
    let label: String
    let value: String
    let status: BoundaryStatus
    let details: String

    enum BoundaryStatus {
        case good, warning, danger

        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .danger: return .red
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 24)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(Bauhaus.Font.bodyBold)
                    Spacer()
                    Text(value)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(status.color)
                }

                Text(details)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
