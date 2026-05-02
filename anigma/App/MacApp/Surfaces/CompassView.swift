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
                    NextCard()

                    // Connected Scopes Card
                    ScopeCard()

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
    }
}

// MARK: - Briefing Band

struct BriefingBand: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            BriefingTile(
                title: "Inbox",
                value: "\(store.artifacts.count)",
                icon: "tray.fill",
                accent: store.artifacts.isEmpty ? .secondary : Bauhaus.Color.accent
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Inbox, \(store.artifacts.count) items")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows your inbox")
            .onTapGesture { store.userSurface = .inbox }

            BriefingTile(
                title: "Projects",
                value: "\(store.workspaces.count)",
                icon: "folder.fill",
                accent: Bauhaus.Color.accent
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Projects, \(store.workspaces.count) active")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows your projects")
            .onTapGesture { store.userSurface = .projects }

            BriefingTile(
                title: "Running",
                value: "\(store.jobs.filter { $0.status.uppercased() == "RUNNING" }.count)",
                icon: "gearshape.2.fill",
                accent: store.hasRunningJobs ? .blue : .secondary
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Running Jobs, \(store.jobs.filter { $0.status.uppercased() == "RUNNING" }.count) active")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens job center")
            .onTapGesture { store.isJobCenterPresented = true }

            BriefingTile(
                title: "Governance",
                value: store.governanceMode.rawValue,
                icon: "checkmark.shield.fill",
                accent: Bauhaus.Color.accent
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Governance Mode, \(store.governanceMode.rawValue)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Manage source connections")
            .onTapGesture { store.isSourceConnectionPresented = true }
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
        .padding(.horizontal, Bauhaus.Grid.x2)
        .padding(.vertical, Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface)
        .overlay(
            Rectangle()
                .fill(accent.opacity(0.3))
                .frame(width: 2),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
    }
}

// MARK: - Now Card

struct NowCard: View {
    @Environment(AppStore.self) private var store
    @State private var isDropTargeted = false

    var body: some View {
        CompassCard(title: "Now", icon: "sun.max.fill") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                if store.hasRunningJobs {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active pipeline")
                            .font(Bauhaus.Font.subHeader)

                        ForEach(Array(store.jobs.filter { $0.status.uppercased() == "RUNNING" }.prefix(2))) { job in
                            HStack {
                                ProgressView().controlSize(.small)
                                Text(job.name).font(Bauhaus.Font.body)
                            }
                        }

                        Button("View Progress") {
                            store.isJobCenterPresented = true
                        }
                        .buttonStyle(.link)
                        .font(Bauhaus.Font.caption)
                    }
                } else if !store.artifacts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unprocessed content")
                            .font(Bauhaus.Font.subHeader)

                        Text("\(store.artifacts.count) items in inbox need review.")
                            .font(Bauhaus.Font.body)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Button("Review Inbox") {
                            store.userSurface = .inbox
                        }
                        .bauhausAccentButton()
                        .accessibilityLabel("Review \(store.artifacts.count) inbox items")
                    }
                } else {
                    // Intake target
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Intake target")
                            .font(Bauhaus.Font.subHeader)
                            .accessibilityAddTraits(.isHeader)

                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(isDropTargeted ? Bauhaus.Color.accent : Bauhaus.Color.textTertiary)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Drop files here")
                                    .font(Bauhaus.Font.body).fontWeight(.medium)
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
                                .stroke(isDropTargeted ? Bauhaus.Color.accent : Bauhaus.Color.border, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { _ in
            true // Link with store upload logic
        }
    }
}

// MARK: - Next Card

struct NextCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        CompassCard(title: "Next", icon: "arrow.right.circle.fill") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                NextActionRow(title: "Import documents", icon: "doc.badge.plus") {
                    store.userSurface = .inbox
                }

                NextActionRow(
                    title: "Start a project",
                    icon: "folder.badge.plus",
                    action: {},
                    wip: (feature: "Project Planning", fallback: "Upload Syllabus", icon: "tray.fill", detour: { store.userSurface = .inbox })
                )

                NextActionRow(
                    title: "Connect external host",
                    icon: "network",
                    action: {},
                    wip: (feature: "External Federation", fallback: "Manage Local Contexts", icon: "shield.lefthalf.filled", detour: { store.isSourceConnectionPresented = true })
                )
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
                Image(systemName: icon).frame(width: 20)
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
                        // Run action
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.systemImage).font(.system(size: 16))
                            Text(action.title).font(Bauhaus.Font.caption).fontWeight(.medium)
                        }
                        .frame(width: 64, height: 50)
                        .background(Bauhaus.Color.surface.opacity(0.5))
                        .cornerRadius(Bauhaus.Grid.cornerRadius)
                    }
                    .buttonStyle(.plain)
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
                if store.jobs.isEmpty {
                    Text("No recent history").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textTertiary)
                } else {
                    Text("\(store.jobs.count) total jobs processed").font(Bauhaus.Font.body)
                    Button("View Logs") { store.userSurface = .activity }
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.accent)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Scope Card

struct ScopeCard: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        CompassCard(title: "Contexts", icon: "shield.lefthalf.filled") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                if store.scopes.isEmpty {
                    Text("No deep contexts mapped.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Button("Connect Sources") {
                        store.isSourceConnectionPresented = true
                    }
                    .bauhausAccentButton()
                    .padding(.top, 4)
                } else {
                    ForEach(store.scopes.prefix(3)) { scope in
                        Button(action: { appState.selectedContextId = scope.id.uuidString }) {
                            HStack {
                                Image(systemName: appState.selectedContextId == scope.id.uuidString ? "checkmark.circle.fill" : "circle")
                                    .font(Bauhaus.Font.caption)
                                    .foregroundStyle(appState.selectedContextId == scope.id.uuidString ? Bauhaus.Color.accent : .secondary)

                                Text(scope.name)
                                    .font(Bauhaus.Font.body)
                                    .foregroundStyle(appState.selectedContextId == scope.id.uuidString ? Bauhaus.Color.textPrimary : .secondary)

                                Spacer()

                                Text(scope.depth.rawValue)
                                    .font(Bauhaus.Font.mono)
                                    .foregroundStyle(Bauhaus.Color.accent)
                            }
                            .padding(4)
                            .background(appState.selectedContextId == scope.id.uuidString ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(scope.name), \(scope.depth.rawValue) context")
                        .accessibilityHint("Selects this context for research")
                        .accessibilityAddTraits(appState.selectedContextId == scope.id.uuidString ? [.isSelected] : [])
                    }

                    Button("Manage Contexts") {
                        store.isSourceConnectionPresented = true
                    }
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .padding(.top, 4)
                }
            }
        }
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

#Preview {
    CompassView()
        .frame(width: 800, height: 600)
}
