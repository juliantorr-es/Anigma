//
//  AtlasView.swift
//  AnigmaAppMac
//
//  Atlas - knowledge map with lenses.
//  Bauhaus identity: flatter planes, sharper edges, visible lens structure.
//

import SwiftUI
import AnigmaClientKit

struct AtlasView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedLens: AtlasLens = .contexts

    var body: some View {
        HSplitView {
            // Lenses Sidebar
            VStack(spacing: 0) {
                Text("Lenses".uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Bauhaus.Grid.x2)
                    .padding(.vertical, 8)
                    .background(Bauhaus.Color.surface)
                    .bauhausSection()

                List(AtlasLens.allCases, selection: $selectedLens) { lens in
                    Label(lens.rawValue, systemImage: lens.icon)
                        .font(Bauhaus.Font.body)
                        .tag(lens)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 160, maxWidth: 220)
            // Map Canvas
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: selectedLens.icon).foregroundStyle(Bauhaus.Color.accent)
                    Text(selectedLens.rawValue).font(Bauhaus.Font.header)
                    Spacer()
                }
                .padding(Bauhaus.Grid.x3)
                .background(Bauhaus.Color.surface)
                .bauhausSection()

                ZStack {
                    CanvasGrid()
                        .accessibilityHidden(true)

                    switch selectedLens {
                    case .contexts:
                        ContextLensView()
                    case .projects:
                        ProjectLensView()
                    case .timeline:
                        TimelineLensView()
                    default:
                        VStack(spacing: 8) {
                            Text("\(selectedLens.rawValue) lens not calibrated.")
                                .font(Bauhaus.Font.subHeader)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                            Text("Import more entity data to enable this view.")
                                .font(Bauhaus.Font.body)
                                .foregroundStyle(Bauhaus.Color.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 400)
        }
    }
}

private struct ContextLensView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: Bauhaus.Grid.x3) {
                ForEach(store.contexts) { context in
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                        HStack {
                            Image(systemName: context.icon)
                                .font(Bauhaus.Font.displayS)
                                .foregroundStyle(Bauhaus.Color.accent)
                            Spacer()
                            if context.id == appState.currentContext?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Bauhaus.Color.trusted)
                            }
                        }

                        Text(context.name)
                            .font(Bauhaus.Font.subHeader)

                        if !context.description.isEmpty {
                            Text(context.description)
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                                .lineLimit(2)
                        }

                        Divider()

                        HStack {
                            Label("\(context.artifactIds.count)", systemImage: "doc.fill")
                            Spacer()
                            Label("\(context.sourceIds.count)", systemImage: "link")
                        }
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                    .padding(Bauhaus.Grid.x3)
                    .background(Bauhaus.Color.surface)
                    .cornerRadius(Bauhaus.Grid.cornerRadius)
                    .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius).stroke(Bauhaus.Color.border, lineWidth: 1))
                    .onTapGesture {
                        store.activateContext(context)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Context: \(context.name)")
                    .accessibilityHint(context.description)
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(Bauhaus.Grid.x4)
        }
    }
}

private struct ProjectLensView: View {
    @Environment(AppStore.self) private var store
    private let projectColumns = [GridItem(.adaptive(minimum: 180))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: projectColumns, spacing: Bauhaus.Grid.x2) {
                ForEach(store.workspaces, id: \.id) { workspace in
                    ProjectCard(workspace: workspace)
                }
            }
            .padding(Bauhaus.Grid.x3)
        }
    }
}

private struct ProjectCard: View {
    let workspace: WorkspaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "folder.fill")
                .font(Bauhaus.Font.displayM)
                .foregroundStyle(Bauhaus.Color.accent)

            Text(workspace.name)
                .font(Bauhaus.Font.bodyBold)
                .lineLimit(1)

            Text("\(workspace.id.prefix(8))")
                .font(Bauhaus.Font.monoSmall)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Bauhaus.Color.trusted)
                Text("Governed")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
        .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall).stroke(Bauhaus.Color.border, lineWidth: 1))
    }
}

private struct TimelineLensView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                    if appState.ledger.isEmpty {
                        Text("No evidence recorded yet.")
                            .font(Bauhaus.Font.body)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                            .padding()
                    } else {
                        ForEach(appState.ledger.reversed()) { evidence in
                        HStack(alignment: .top, spacing: Bauhaus.Grid.x3) {
                            // Timeline Line
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Bauhaus.Color.accent)
                                    .frame(width: Bauhaus.Grid.x1, height: Bauhaus.Grid.x1)
                                Rectangle()
                                    .fill(Bauhaus.Color.border)
                                    .frame(width: 2) // OK: Timeline line width
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(width: Bauhaus.Grid.x3)

                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(evidence.type.rawValue.uppercased())
                                        .font(Bauhaus.Font.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Bauhaus.Color.accent)
                                    Spacer()
                                    Text(evidence.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(Bauhaus.Font.caption)
                                        .foregroundStyle(Bauhaus.Color.textTertiary)
                                }

                                Text(evidence.summary)
                                    .font(Bauhaus.Font.body)

                                if let hash = evidence.hash {
                                    Text("SHA: \(hash.prefix(8))...")
                                        .font(Bauhaus.Font.mono)
                                        .foregroundStyle(Bauhaus.Color.textSecondary)
                                }
                            }
                            .padding(.bottom, Bauhaus.Grid.x4)
                        }
                    }
                }
            }
            .padding(Bauhaus.Grid.x4)
        }
    }
}

#Preview {
    AtlasView()
        .frame(width: 800, height: 500) // OK: Preview sizing
}
