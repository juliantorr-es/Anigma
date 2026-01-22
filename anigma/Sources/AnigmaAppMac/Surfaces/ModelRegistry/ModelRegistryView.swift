//
//  ModelRegistryView.swift
//  AnigmaAppMac
//
//  Model Registry browser - shows installed models, trust tiers, compatibility.
//  Phase 5: UX that doesn't lie to users.
//

import SwiftUI
import ContractsCore
import AnigmaCore
import AnigmaCLI

public struct ModelRegistryView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedTab: Tab = .installed

    public enum Tab: String, CaseIterable, Identifiable {
        case installed = "Installed"
        case browse = "Browse"
        case downloads = "Downloads"
        case storage = "Storage"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .installed: return "square.stack.3d.up"
            case .browse: return "magnifyingglass"
            case .downloads: return "arrow.down.circle"
            case .storage: return "externaldrive"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                InstalledModelsView()
                    .tag(Tab.installed)

                ModelBrowserView()
                    .tag(Tab.browse)

                ActiveDownloadsView()
                    .tag(Tab.downloads)

                StorageManagementView()
                    .tag(Tab.storage)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .task {
            await refreshData()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Bauhaus.Color.surface : Color.clear)
                    .foregroundStyle(selectedTab == tab ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)
                }
                .buttonStyle(.plain)

                if tab != Tab.allCases.last {
                    Rectangle()
                        .fill(Bauhaus.Color.border)
                        .frame(width: 1, height: 20)
                }
            }

            Spacer()

            // Quick actions
            HStack(spacing: 12) {
                Button {
                    Task {
                        await refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")

                Button {
                    selectedTab = .browse
                } label: {
                    Image(systemName: "plus.circle")
                }
                .help("Browse Models")
            }
            .padding(.trailing, 16)
        }
        .background(Bauhaus.Color.background)
    }

    private func refreshData() async {
        await appStore.modelRegistry.refreshModels()
    }
}

struct InstalledModelsView: View {
    @Environment(AppStore.self) private var appStore
    @State private var models: [ModelRegistryEntry] = []

    var body: some View {
        Group {
            if models.isEmpty {
                ContentUnavailableView(
                    "No Models Installed",
                    systemImage: "square.stack.3d.up",
                    description: Text("Download models from HuggingFace to get started")
                )
            } else {
                List(models, id: \.modelId) { model in
                    InstalledModelRow(model: model)
                }
                .listStyle(.plain)
            }
        }
        .task {
            models = await appStore.modelRegistry.installedModels
        }
    }
}

struct InstalledModelRow: View {
    let model: ModelRegistryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.modelId)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let backend = model.backendCompatibility?.preferredBackend {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(backend)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                        Text(model.trustTier ?? "unknown")
                    }
                    .font(.caption)
                    .foregroundStyle(trustColor)
                }
            }

            Spacer()

            Button("Open") {
                // Open model location
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private var trustColor: Color {
        switch model.trustTier?.lowercased() {
        case "first-class":
            return .green
        case "compatible":
            return .blue
        case "experimental":
            return .orange
        case "quarantined":
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    ModelRegistryView()
        .frame(minWidth: 800, minHeight: 600)
}
