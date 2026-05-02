//
//  StudioView.swift
//  AnigmaAppMac
//
//  Studio - tool builder workbench.
//  Bauhaus style: flatter panes, sharp edges, visible layout markers.
//

import SwiftUI

struct StudioView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HSplitView {
            // Left: Parts bin (Subtle, secondary)
            PartsBin()
                .frame(minWidth: 200, maxWidth: 280)
                .accessibilityLabel("Parts Library")

            // Center: Flow canvas (The Workshop)
            FlowCanvas()
                .frame(minWidth: 400)
                .accessibilityLabel("Workflow Canvas")

            // Right: Truth Inspector (Contract/Preview/Evidence)
            StudioTruthPanel()
                .frame(minWidth: 280, maxWidth: 360)
                .accessibilityLabel("Truth Inspector")
        }
        .navigationTitle("Studio")
    }
}

// MARK: - Parts Bin

struct PartsBin: View {
    @State private var searchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Parts".uppercased())
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Bauhaus.Grid.x2)
                .padding(.vertical, Bauhaus.Grid.unit)
                .background(Bauhaus.Color.surface)
                .bauhausSection()

            List {
                Section("Input") {
                    PartRow(name: "File Input", icon: "doc.fill")
                    PartRow(name: "JSON Parser", icon: "curlybraces")
                }
                Section("Transform") {
                    PartRow(name: "OCR Engine", icon: "doc.text.viewfinder")
                    PartRow(name: "Summarizer", icon: "text.quote")
                    PartRow(name: "Translator", icon: "globe")
                }
                Section("Output") {
                    PartRow(name: "To Inbox", icon: "tray.fill")
                    PartRow(name: "Export Disk", icon: "arrow.down.doc.fill")
                }
            }
            .listStyle(.sidebar)
        }
        .background(Bauhaus.Color.surface)
    }
}

struct PartRow: View {
    let name: String
    let icon: String
    @State private var isShowingWIP = false

    var body: some View {
        Button {
            isShowingWIP = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.accent)
                Text(name).font(Bauhaus.Font.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .accessibilityLabel(name)
        .accessibilityHint("Add \(name) to canvas")
        .popover(isPresented: $isShowingWIP) {
            WIPPopover(feature: name, fallback: "Use Studio Template", fallbackIcon: "hammer.fill") {
                isShowingWIP = false
            }
        }
    }
}

struct FlowCanvas: View {
    var body: some View {
        ZStack {
            CanvasGrid()

            VStack {
                Text("Flow Canvas Area")
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                Text("Drag parts here to build tools.")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }
        }
        .background(Bauhaus.Color.background)
        .clipped()
    }
}

// MARK: - Truth Panel

struct StudioTruthPanel: View {
    @State private var selectedTab = 0
    @State private var isShowingExportWIP = false

    var body: some View {
        VStack(spacing: 0) {
            // Bauhaus Tabs
            HStack(spacing: 0) {
                TruthTab(title: "Contract", isSelected: selectedTab == 0) { selectedTab = 0 }
                    .accessibilityLabel("Contract Tab")
                    .accessibilityAddTraits(selectedTab == 0 ? [.isSelected] : [])
                TruthTab(title: "Preview", isSelected: selectedTab == 1) { selectedTab = 1 }
                    .accessibilityLabel("Preview Tab")
                    .accessibilityAddTraits(selectedTab == 1 ? [.isSelected] : [])
                TruthTab(title: "Evidence", isSelected: selectedTab == 2) { selectedTab = 2 }
                    .accessibilityLabel("Evidence Tab")
                    .accessibilityAddTraits(selectedTab == 2 ? [.isSelected] : [])
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    if selectedTab == 0 {
                        Text("Drafting Contract…").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
                    } else if selectedTab == 1 {
                        Text("No data to preview.").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
                    } else {
                        Text("Evidence chain empty.").font(Bauhaus.Font.body).foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }

            Divider()

            Button("Export Contract") {
                isShowingExportWIP = true
            }
            .bauhausAccentButton()
            .padding(Bauhaus.Grid.x2)
            .popover(isPresented: $isShowingExportWIP) {
                WIPPopover(feature: "Contract Export", fallback: "View Evidence Log", fallbackIcon: "list.bullet.rectangle") {
                    isShowingExportWIP = false
                }
            }
        }
        .background(Bauhaus.Color.surface)
    }
}

#Preview {
    StudioView()
        .frame(width: 1000, height: 600)
}

#Preview {
    StudioView()
        .frame(width: 1000, height: 600)
}
