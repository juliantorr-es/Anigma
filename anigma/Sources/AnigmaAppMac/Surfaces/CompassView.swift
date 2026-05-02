//
//  CompassView.swift
//  AnigmaAppMac
//
//  Life compass - briefing plus launchpad.
//  Bauhaus identity: flatter planes, sharper edges, intentional accents.
//

import SwiftUI
import AnigmaClientKit

struct CompassView: View {
    @Environment(AppStore.self) private var store
    @State private var isProjectPlanningPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {

                // Briefing Band - at-a-glance truth
                BriefingBand()

                // Dominant Grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 340, maximum: 500), spacing: Bauhaus.Grid.x3)
                ], spacing: Bauhaus.Grid.x3) {

                    // Now Card - dominated by immediate priority
                    NowCard()

                    // Next Card - concrete single-tap actions
                    NextCard(isProjectPlanningPresented: $isProjectPlanningPresented)

                    // Connected Contexts Card
                    ContextCard()

                    // Pinned Card - action dock
                    PinnedCard()

                    // Activity Card - status summary
                    ActivityCard()
                }
            }
            .padding(Bauhaus.Grid.x3)
        }
        .navigationTitle("Compass")
        .background(Bauhaus.Color.background)
        .sheet(isPresented: $isProjectPlanningPresented) {
            ProjectPlanningView()
        }
    }
}

// MARK: - Briefing Band

struct BriefingBand: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        let runningJobs = store.jobs.filter { $0.status.uppercased() == "RUNNING" }.count + store.localJobs.filter { $0.status == .running }.count

        HStack(spacing: Bauhaus.Grid.x2) {
            Button {
                store.userSurface = .inbox
            } label: {
                BriefingTile(
                    title: "Inbox",
                    value: "\(appState.intakeQueue.count)",
                    icon: "tray.fill",
                    accent: appState.intakeQueue.isEmpty ? Bauhaus.Color.textSecondary : Bauhaus.Color.accentHighContrast
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Inbox, \(appState.intakeQueue.count) items")
            .accessibilityHint("Open inbox to triage items")
            .accessibilityAddTraits(.isButton)

            Button {
                store.isJobCenterPresented = true
            } label: {
                BriefingTile(
                    title: "Active Jobs",
                    value: "\(runningJobs)",
                    icon: "gearshape.2.fill",
                    accent: store.hasRunningJobs ? Bauhaus.Color.accentHighContrast : Bauhaus.Color.textSecondary
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Active jobs, \(runningJobs) running")
            .accessibilityHint("Open job center to review progress")
            .accessibilityAddTraits(.isButton)

            Button {
                store.userSurface = .activity
            } label: {
                BriefingTile(
                    title: "Evidence",
                    value: "\(appState.ledger.count)",
                    icon: "checkmark.seal.fill",
                    accent: appState.ledger.isEmpty ? Bauhaus.Color.textSecondary : Bauhaus.Color.accentHighContrast
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Evidence ledger, \(appState.ledger.count) entries")
            .accessibilityHint("Open activity to review receipts")
            .accessibilityAddTraits(.isButton)

            Button {
                store.isSourceConnectionPresented = true
            } label: {
                BriefingTile(
                    title: "Governance",
                    value: store.governanceMode.rawValue,
                    icon: "shield.check.fill",
                    accent: Bauhaus.Color.accentHighContrast
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Governance Mode, \(store.governanceMode.rawValue)")
            .accessibilityHint("Manage governance and source connections")
            .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BriefingTile: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(accent)
                Text(title.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Text(value)
                .font(Bauhaus.Font.statNumber)
                .foregroundStyle(Bauhaus.Color.textHighContrast)
        }
        .padding(.horizontal, Bauhaus.Grid.x2)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(Bauhaus.Color.cardBackground.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                .stroke(accent.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Now Card

struct NowCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var isDropTargeted = false

    var body: some View {
        CompassCard(title: "Now", icon: "sun.max.fill") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                if store.hasRunningJobs {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active pipeline")
                            .font(Bauhaus.Font.subHeader)

                        ForEach(Array(store.localJobs.filter { $0.status == .running }.prefix(2))) { job in
                            HStack {
                                ProgressView(value: job.progress).controlSize(.small)
                                    .frame(width: Bauhaus.Grid.x5)
                                Text(job.title).font(Bauhaus.Font.body)
                            }
                        }

                        ForEach(Array(store.jobs.filter { $0.status.uppercased() == "RUNNING" }.prefix(2))) { job in
                            HStack {
                                ProgressView().controlSize(.small)
                                Text(job.name).font(Bauhaus.Font.body)
                            }
                        }

                        Button("View Progress") { // tertiaryButtonStyle
                            store.isJobCenterPresented = true
                        }
                        .buttonStyle(.bordered)
                        .font(Bauhaus.Font.caption)
                        .accessibilityLabel("View job progress")
                        .accessibilityHint("Opens job center to see running tasks")
                    }
                } else if !appState.intakeQueue.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unprocessed content")
                            .font(Bauhaus.Font.subHeader)

                        Text("\(appState.intakeQueue.count) items in inbox need review.")
                            .font(Bauhaus.Font.body)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Button("Review Inbox") { // primaryButtonStyle
                            store.userSurface = .inbox
                        }
                        .primaryButtonStyle()
                        .accessibilityLabel("Review \(appState.intakeQueue.count) inbox items")
                    }
                } else {
                    // Intake target
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Intake target")
                            .font(Bauhaus.Font.subHeader)
                            .accessibilityAddTraits(.isHeader)

                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(Bauhaus.Font.displayS)
                                .foregroundStyle(isDropTargeted ? Bauhaus.Color.accentHighContrast : Bauhaus.Color.textTertiary)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Drop files here")
                                    .font(Bauhaus.Font.bodyBold)
                                Text("PDF, images, JSON")
                                    .font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Drop zone for files")
                        .accessibilityHint("Drag and drop PDF, images, or JSON files here to import")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Bauhaus.Grid.x2)
                        .background(Bauhaus.Color.surface.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                                .stroke(isDropTargeted ? Bauhaus.Color.accentHighContrast : Bauhaus.Color.border, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            store.handleIntake(providers)
            return true
        }
    }
}

// MARK: - Next Card

struct NextCard: View {
    @Environment(AppStore.self) private var store
    @Binding var isProjectPlanningPresented: Bool

    var body: some View {
        CompassCard(title: "Next", icon: "arrow.right.circle.fill") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                NextActionRow(title: "Import documents", icon: "doc.badge.plus") {
                    store.userSurface = .inbox
                }

                NextActionRow(
                    title: "Start a project",
                    icon: "folder.badge.plus"
                )                    { isProjectPlanningPresented = true }

                NextActionRow(
                    title: "Connect external host",
                    icon: "network"
                )                    { store.isSourceConnectionPresented = true }
            }
        }
    }
}

struct NextActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    var wip: (feature: String, fallback: String, icon: String, detour: () -> Void)?

    @State private var isShowingWIP = false

    var body: some View {
        Button {
            if wip != nil {
                isShowingWIP = true
            } else {
                action()
            }
        } label: {
            HStack {
                Image(systemName: icon).frame(width: Bauhaus.Grid.x2 + 4) // 20 roughly
                Text(title).font(Bauhaus.Font.body)
                Spacer()
                Image(systemName: "chevron.right").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
            }
            .padding(Bauhaus.Grid.unit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(wip != nil ? "Feature coming soon" : "Perform action")
        .popover(isPresented: $isShowingWIP) {
            if let w = wip {
                WIPPopover(feature: w.feature, fallback: w.fallback, fallbackIcon: w.icon) {
                    isShowingWIP = false
                    w.detour()
                }
            }
        }
    }
}

// MARK: - Pinned Card

struct PinnedCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        CompassCard(title: "Pinned", icon: "pin.fill") {
            HStack(spacing: Bauhaus.Grid.unit) {
                    ForEach(Array(store.pinnedActions)) { action in
                        Button {
                            Task {
                                await store.runPinnedAction(action)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: action.systemImage).font(Bauhaus.Font.icon)
                                Text(action.title).font(Bauhaus.Font.caption).fontWeight(.medium)
                            }
                            .frame(width: Bauhaus.Grid.x8, height: 50)
                        .background(Bauhaus.Color.surface.opacity(0.5))
                        .cornerRadius(Bauhaus.Grid.radius)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Run \(action.title)")
                }
            }
        }
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        CompassCard(title: "Activity", icon: "clock.fill") {
            VStack(alignment: .leading, spacing: 4) {
                let totalJobs = store.jobs.count + store.localJobs.count
                if totalJobs == 0 {
                    Text("No recent history").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textTertiary)
                } else {
                    Text("\(totalJobs) total jobs processed").font(Bauhaus.Font.body)
                    Button("View Logs") { store.userSurface = .activity } // tertiaryButtonStyle
                        .buttonStyle(.bordered)
                        .font(Bauhaus.Font.caption)
                        .padding(.top, 4)
                        .accessibilityLabel("View activity logs")
                        .accessibilityHint("Opens activity view to see job history")
                }
            }
        }
    }
}

// MARK: - Context Card (The Spine)

struct ContextCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        CompassCard(title: "Contexts", icon: "arrow.triangle.branch") {
            contextCardContent
        }
    }

    @ViewBuilder
    private var contextCardContent: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            if store.contexts.isEmpty {
                emptyContextView
            } else {
                contextsList
                manageButton
            }
        }
    }

    @ViewBuilder
    private var emptyContextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No active contexts.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Button {
                store.userSurface = .inbox
            } label: {
                Label("Import Documents", systemImage: "plus")
            }
            .primaryButtonStyle()
            .accessibilityLabel("Import documents")
            .accessibilityHint("Opens inbox to import new documents")
        }
    }

    @ViewBuilder
    private var contextsList: some View {
        ForEach(store.contexts.prefix(3)) { context in
            contextRowButton(for: context)
        }
    }

    @ViewBuilder
    private var manageButton: some View {
        Button("Manage Contexts") {
            store.isSourceConnectionPresented = true
        }
        .buttonStyle(.bordered)
        .font(Bauhaus.Font.caption)
        .foregroundStyle(Bauhaus.Color.textSecondary)
        .padding(.vertical, 4)
        .accessibilityLabel("Manage contexts")
        .accessibilityHint("Opens source connection view to manage knowledge contexts")
    }

    private func contextRowButton(for context: AnigmaContext) -> some View {
        Button(action: { store.activateContext(context) }) {
            HStack {
                Image(systemName: appState.currentContext?.id == context.id ? "largecircle.fill.circle" : "circle")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(appState.currentContext?.id == context.id ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.name)
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    Text(context.description)
                        .font(Bauhaus.Font.caption)
                        .lineLimit(1)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }

                Spacer()

                Image(systemName: context.icon)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .padding(Bauhaus.Grid.unit)
            .background(appState.currentContext?.id == context.id ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
            .cornerRadius(Bauhaus.Grid.radius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Activate context: \(context.name)")
        .accessibilityHint(context.description)
        .accessibilityAddTraits(appState.currentContext?.id == context.id ? [.isSelected] : [])
    }
}

// MARK: - Supporting Views

struct CompassCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Bauhaus.Color.accent)
                Text(title.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                Spacer()
            }

            content
        }
        .bauhausCard()
    }
}
