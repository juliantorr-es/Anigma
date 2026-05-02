//
//  AskView.swift
//  AnigmaAppMac
//
//  Ask - governed AI research panel.
//  The OmniBar is the primary input. This surface shows suggested paths.
//

import SwiftUI

struct AskView: View {
    @Environment(AppStore.self) private var store
    @State private var recentQueries: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {

                // Active Context Status
                ContextBanner()

                // Suggested Paths
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    Text("Research paths")
                        .font(Bauhaus.Font.subHeader)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: Bauhaus.Grid.unit) {
                        SuggestedPathRow(title: "Analyze key deadlines", subtitle: "Extract timeline from imported documents", icon: "calendar.badge.clock") {
                            Task { await store.submitJob(action: "extract_deadlines", parameters: [:]) }
                        }
                        SuggestedPathRow(title: "Synthesize themes", subtitle: "Compare topics across all project items", icon: "doc.text.magnifyingglass") {
                            Task { await store.submitJob(action: "summarize", parameters: [:]) } // Using summarize as proxy for synthesis
                        }
                        SuggestedPathRow(title: "Validate evidence", subtitle: "Check claims against recent receipts", icon: "checkmark.shield.fill") {
                            Task { await store.submitJob(action: "verify_claims", parameters: [:]) }
                        }
                        SuggestedPathRow(title: "Draft response", subtitle: "Generate starting point based on context", icon: "square.and.pencil") {
                            Task { await store.submitJob(action: "generate_response", parameters: [:]) }
                        }
                    }
                }

                // Recent activity
                if !recentQueries.isEmpty {
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                        Text("Recent")
                            .font(Bauhaus.Font.subHeader)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        ForEach(recentQueries, id: \.self) { query in
                            HStack {
                                Image(systemName: "sparkles").foregroundStyle(Bauhaus.Color.accent)
                                Text(query).font(Bauhaus.Font.body)
                                Spacer()
                            }
                            .padding(Bauhaus.Grid.unit)
                            .background(Bauhaus.Color.surface)
                            .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
                        }
                    }
                }
            }
            .padding(Bauhaus.Grid.x3)
        }
        .navigationTitle("Ask")
        .background(Bauhaus.Color.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Start new search/research if needed
                } label: {
                    Label("New Research", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("New research path")
            }
        }
    }
}

// MARK: - Components

struct ContextBanner: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            let current = appState.currentContext

            // Icon
            Image(systemName: current != nil ? current!.icon : (store.contexts.isEmpty ? "exclamationmark.triangle.fill" : "arrow.triangle.branch"))
                .font(Bauhaus.Font.displayS)
                .foregroundStyle(current != nil ? Bauhaus.Color.accent : (store.contexts.isEmpty ? Bauhaus.Color.warning : Bauhaus.Color.textSecondary))

            // Text & Selector
            VStack(alignment: .leading, spacing: 2) {
                if let context = current {
                    HStack {
                        Text("Active Context: \(context.name)")
                            .font(Bauhaus.Font.subHeader)

                        Menu {
                            ForEach(store.contexts) { ctx in
                                Button {
                                    store.activateContext(ctx)
                                } label: {
                                    Label(ctx.name, systemImage: ctx.id == context.id ? "checkmark" : "")
                                }
                            }
                            Divider()
                            Button("Manage Contexts...") { store.isSourceConnectionPresented = true } // plain ButtonStyle
                                .accessibilityLabel("Manage contexts")
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                                .font(Bauhaus.Font.caption)
                                .accessibilityLabel("Change context")
                        }
                        .menuStyle(.borderlessButton)
                        .keyboardShortcut("l", modifiers: .command) // 'L' for Lens/Context
                    }

                    Text("Governed research enabled within this lens.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                } else if store.contexts.isEmpty {
                    Text("No context available")
                        .font(Bauhaus.Font.subHeader)
                    Text("Connect sources to enable governed research.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                } else {
                    HStack {
                        Text("No context selected")
                            .font(Bauhaus.Font.subHeader)

                        Menu {
                            ForEach(store.contexts) { ctx in
                                Button {
                                    store.activateContext(ctx)
                                } label: {
                                    Label(ctx.name, systemImage: "")
                                }
                            }
                            Divider()
                            Button("Manage Contexts...") { store.isSourceConnectionPresented = true } // plain ButtonStyle
                                .accessibilityLabel("Manage contexts")
                        } label: {
                            Text("Select Context")
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.accent)
                                .accessibilityLabel("Select active context")
                        }
                        .menuStyle(.borderlessButton)
                        .keyboardShortcut("l", modifiers: .command)
                    }
                    Text("Select a context to focus research.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
            .accessibilityElement(children: .contain)

            Spacer()

            if store.contexts.isEmpty {
                Button("Connect Sources") { // primaryButtonStyle
                    store.isSourceConnectionPresented = true
                }
                .primaryButtonStyle()
                .accessibilityLabel("Connect Sources")
                .accessibilityHint("Opens wizard to connect knowledge sources")
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

struct SuggestedPathRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { // plain ButtonStyle
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(Bauhaus.Font.headline)
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: Bauhaus.Grid.x4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Bauhaus.Font.bodyBold)
                    Text(subtitle).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to start this research path")
    }
}
