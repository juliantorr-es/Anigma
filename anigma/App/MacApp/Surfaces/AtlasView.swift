//
//  AtlasView.swift
//  AnigmaAppMac
//
//  Atlas - knowledge map with lenses.
//  Bauhaus identity: flatter planes, sharper edges, visible lens structure.
//

import SwiftUI

struct AtlasView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedLens: AtlasLens = .people

    var body: some View {
        VStack(spacing: 0) {
            if store.artifacts.isEmpty {
                AtlasEmptyState()
            } else {
                AtlasContent(selectedLens: $selectedLens)
            }
        }
        .navigationTitle("Atlas")
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Empty State

struct AtlasEmptyState: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x4) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundStyle(Bauhaus.Color.borderStrong)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Knowledge Map Empty")
                    .font(Bauhaus.Font.header)
                    .accessibilityAddTraits(.isHeader)

                if store.mode == .insight {
                    Text("Connect sources to start mapping relationships, timelines, and provenance.")
                        .font(Bauhaus.Font.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .padding(.horizontal, Bauhaus.Grid.x4)
                } else {
                    Text("Import documents to begin mapping relationships and entities.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                Button("Connect Sources") {
                    store.isSourceConnectionPresented = true
                }
                .bauhausAccentButton()
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

// MARK: - Content

struct AtlasContent: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedLens: AtlasLens

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

                    Text("Atlas is synthesizing relationships…")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Map Canvas: Atlas is synthesizing relationships")
            }
            .frame(minWidth: 400)
        }
    }
}

#Preview {
    AtlasView()
        .frame(width: 800, height: 500)
}
