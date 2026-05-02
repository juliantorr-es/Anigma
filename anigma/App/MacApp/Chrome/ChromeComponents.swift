//
//  ChromeComponents.swift
//  AnigmaAppMac
//
//  Toolbar chrome components that read from store.
//

import SwiftUI

struct GovernanceChip: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Button {
            store.isSourceConnectionPresented = true
        } label: {
            HStack(spacing: 4) {
                // Compute
                StatusPill(label: "Compute: Local", icon: "cpu", color: .secondary)

                // Data
                let hasExternal = store.sources.contains { $0.type == .email }
                StatusPill(label: hasExternal ? "Data: External" : "Data: Local", icon: "cylinder.split.1x2", color: hasExternal ? .orange : .secondary)

                // Network
                let networkOpen = store.privacySettings.allowCloudAI
                StatusPill(label: networkOpen ? "Net: Open" : "Net: Off", icon: "network", color: networkOpen ? .orange : .secondary)
            }
            .padding(4)
            .background(Bauhaus.Color.surface)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusPill: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 8))
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .cornerRadius(3)
    }
}

struct JobCenterButton: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        Button {
            store.isJobCenterPresented = true
        } label: {
            HStack(spacing: Bauhaus.Grid.unit) {
                if store.hasRunningJobs {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 11))
                        .symbolEffect(.pulse)

                    Text(currentVerb)
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11))
                }

                if !store.jobs.isEmpty {
                    Text("\(store.jobs.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(store.hasRunningJobs ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(store.hasRunningJobs ? Bauhaus.Color.accent.opacity(0.2) : Bauhaus.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $bindableStore.isJobCenterPresented, arrowEdge: .bottom) {
            JobCenterPanel()
        }
    }

    private var currentVerb: String {
        guard let active = store.jobs.first(where: { $0.status.uppercased() == "RUNNING" }) else { return "Ready" }
        return active.name.components(separatedBy: " ").first ?? "Active"
    }
}

struct RoleChip: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        Menu {
            ForEach(AnigmaRole.allCases) { r in
                Button(r.displayName) {
                    store.role = r
                }
            }
        } label: {
            HStack(spacing: Bauhaus.Grid.unit) {
                Image(systemName: roleIcon)
                    .font(.system(size: 12))
                Text(store.role.displayName)
                    .font(Bauhaus.Font.caption)
            }
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, Bauhaus.Grid.unit)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }

    private var roleIcon: String {
        switch store.role {
        case .user: return "person.fill"
        case .worker: return "hammer.fill"
        case .admin: return "gearshape.fill"
        case .developer: return "terminal.fill"
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let title: String
    let icon: String
    var count: Int?
    var status: Bauhaus.StatusState?
    var statusText: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(Bauhaus.Color.accent)

            Text(title)
                .font(Bauhaus.Font.body)

            Spacer(minLength: 8)

            if let statusText {
                Text(statusText)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            if let status {
                Bauhaus.StatusDot(state: status)
            }

            if let count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(countColor.opacity(0.1))
                    .foregroundStyle(countColor)
                    .cornerRadius(4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessbilityLabelString)
    }

    private var accessbilityLabelString: String {
        var components = [title]
        if let count = count, count > 0 {
            components.append("\(count) items")
        }
        if let statusText = statusText {
            components.append(statusText)
        }
        return components.joined(separator: ", ")
    }

    private var countColor: Color {
        Bauhaus.Color.textSecondary
    }
}

// MARK: - WIP Utility

struct WIPPopover: View {
    let feature: String
    let fallback: String
    let fallbackIcon: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(Bauhaus.Color.accent)
                Text(feature)
                    .font(Bauhaus.Font.subHeader)
            }

            Text("This feature is currently under construction. Anigma is building the necessary governance contracts.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Divider()

            Button {
                action()
            } label: {
                HStack {
                    Image(systemName: fallbackIcon)
                    Text("Detour: \(fallback)")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 10))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Bauhaus.Color.accent.opacity(0.1))
                .foregroundStyle(Bauhaus.Color.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280)
    }
}

#Preview {
    HStack {
        GovernanceChip()
        RoleChip()
    }
    .padding()
}
