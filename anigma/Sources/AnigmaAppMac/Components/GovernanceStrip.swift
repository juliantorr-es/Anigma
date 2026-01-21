//
//  GovernanceStrip.swift
//  AnigmaAppMac
//
//  Persistent governance status indicator for the main window chrome.
//  Shows: Current Role, Governance Mode, Network Status.
//  Clicking opens the "Why is it in this mode?" inspector.
//

import SwiftUI

// NonPersistent
struct GovernanceStrip: View, Sendable {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var showGovernanceDetails = false
    @State private var showNetworkDetails = false
    @State private var isJobCenterPresented = false

    var body: some View {
        HStack(spacing: Bauhaus.Grid.x2) {

            // 1. Role Indicator (Unlock Play)
            Button(action: { /* Navigate to Role Switcher (future) */   }) {
                HStack(spacing: 6) {
                    Image(systemName: roleIcon)
                    Text(store.role.rawValue.uppercased())
                        .font(Bauhaus.Font.caption)
                        .bold()
                }
                .padding(.horizontal, Bauhaus.Grid.unit)
                .padding(.vertical, Bauhaus.Grid.unit / 2)
                .background(Bauhaus.Color.border)
                .cornerRadius(Bauhaus.Grid.unit / 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Current role: \(store.role.rawValue)")
            .accessibilityHint("Role switching is currently disabled")

            Divider()
                .frame(height: 12) // OK: Divider height

            // 3. Global Job Center
            Button(action: { isJobCenterPresented.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                    if appState.runningJobsCount > 0 {
                        Text("\(appState.runningJobsCount)")
                            .font(Bauhaus.Font.monoBold)
                    }
                }
                .foregroundStyle(appState.runningJobsCount > 0 ? Bauhaus.Color.running : Bauhaus.Color.textSecondary)
                .padding(.horizontal, Bauhaus.Grid.unit)
                .padding(.vertical, Bauhaus.Grid.unit / 2)
                .background(appState.runningJobsCount > 0 ? Bauhaus.Color.running.opacity(0.1) : Color.clear)
                .cornerRadius(Bauhaus.Grid.unit / 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appState.runningJobsCount > 0 ? "Job Center: \(appState.runningJobsCount) running" : "Job Center")
            .accessibilityHint("Shows active jobs and history")
            .popover(isPresented: $isJobCenterPresented) {
                JobCenterPanel()
                    .frame(width: 400, height: 500) // OK: Popover size
            }

            Divider()
                .frame(height: 12) // OK: Divider height

            // 4. Boundary Pill
            HStack(spacing: 0) {
                // Compute Segment
                Button(action: { showGovernanceDetails.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(Bauhaus.Font.small)
                        Text("LOCAL")
                            .font(Bauhaus.Font.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, Bauhaus.Grid.unit)
                    .padding(.vertical, Bauhaus.Grid.unit / 2)
                    .background(Bauhaus.Color.accent.opacity(0.15))
                    .foregroundStyle(Bauhaus.Color.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Trust Boundary: Local")
                .accessibilityHint("Opens trust boundary settings")
                .popover(isPresented: $showGovernanceDetails) {
                    TrustBoundaryPanel()
                }

                Divider()
                    .frame(height: 12) // OK: Divider height

                // Sources Segment
                Button(action: { store.isSourceConnectionPresented.toggle() }) {
                    HStack(spacing: 4) {
                        Text("SOURCES")
                            .font(Bauhaus.Font.caption)
                            .fontWeight(.bold)
                        Circle()
                            .fill(store.isOnline ? Bauhaus.Color.warning : Bauhaus.Color.textTertiary)
                            .frame(width: 6, height: 6) // OK: Dot size
                    }
                    .padding(.horizontal, Bauhaus.Grid.unit)
                    .padding(.vertical, Bauhaus.Grid.unit / 2)
                    .background(Bauhaus.Color.border)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sources Status: \(store.isOnline ? "Online" : "Offline")")
                .accessibilityHint("Manage data sources")
            }
            .cornerRadius(Bauhaus.Grid.unit / 2)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.unit / 2)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, Bauhaus.Grid.x3)
        .padding(.vertical, Bauhaus.Grid.x2)
        .background(Bauhaus.Color.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1) // OK: Divider height
                .foregroundStyle(Bauhaus.Color.border),
            alignment: .bottom
        )
    }

    // MARK: - Computed Props

    var roleIcon: String {
        switch store.role {
        case .user: return "person.fill"
        case .worker: return "hammer.fill"
        case .admin: return "shazam.logo.fill"  // Visual metaphor for control
        case .developer: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var governanceColor: SwiftUI.Color {
        switch store.governanceMode {
        case .local: return Bauhaus.Color.governanceAllowed
        case .verify: return Bauhaus.Color.running
        case .trusted: return Bauhaus.Color.warning
        case .off: return Bauhaus.Color.error
        }
    }
}

// MARK: - Details Panel
// "Why is it in this mode?"

struct GovernanceDetailsPanel: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            Text("Governance State")
                .font(Bauhaus.Font.subHeader)

            VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                LabeledContent("Mode", value: store.governanceMode.rawValue)
                LabeledContent("Enforcement", value: "Hardware & Daemon")

                Divider()

                Text(modeDescription)
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("View Policy Log") {
                // Future: Open Admin Log
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("View policy log")
        }
        .padding(Bauhaus.Grid.x4)
    }

    var modeDescription: String {
        switch store.governanceMode {
        case .local: return "Processing happens on-device by default."
        case .verify: return "Verification receipts required for all results."
        case .trusted: return "Running on a verified, trusted remote host."
        case .off: return "Ungoverned mode. No verification receipts."
        }
    }
}
