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
                        SuggestedPathRow(title: "Analyze key deadlines", subtitle: "Extract timeline from imported documents", icon: "calendar.badge.clock")
                        SuggestedPathRow(title: "Synthesize themes", subtitle: "Compare topics across all project items", icon: "doc.text.magnifyingglass")
                        SuggestedPathRow(title: "Validate evidence", subtitle: "Check claims against recent receipts", icon: "checkmark.shield.fill")
                        SuggestedPathRow(title: "Draft response", subtitle: "Generate starting point based on context", icon: "square.and.pencil")
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
    }
}

// MARK: - Components

struct ContextBanner: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            let selectedScope = store.scopes.first { $0.id.uuidString == appState.selectedContextId }

            Image(systemName: selectedScope != nil ? "checkmark.shield.fill" : (store.scopes.isEmpty ? "exclamationmark.triangle.fill" : "shield.lefthalf.filled"))
                .font(.system(size: 24))
                .foregroundStyle(selectedScope != nil ? Bauhaus.Color.trusted : (store.scopes.isEmpty ? Bauhaus.Color.warning : .secondary))

            VStack(alignment: .leading, spacing: 2) {
                if let scope = selectedScope {
                    Text("Active Context: \(scope.name)")
                        .font(Bauhaus.Font.subHeader)
                    Text("Governed research enabled within this scope.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                } else if store.scopes.isEmpty {
                    Text("No context available")
                        .font(Bauhaus.Font.subHeader)
                    Text("Connect sources to enable governed research.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                } else {
                    Text("No context selected")
                        .font(Bauhaus.Font.subHeader)
                    Text("Select a context from Compass to focus research.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)

            Spacer()

            if store.scopes.isEmpty {
                Button("Connect Sources") {
                    store.isSourceConnectionPresented = true
                }
                .bauhausAccentButton()
            } else {
                Button("Manage Contexts") {
                    store.isSourceConnectionPresented = true
                }
                .buttonStyle(.link)
                .font(Bauhaus.Font.caption)
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

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Bauhaus.Font.body).fontWeight(.medium)
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
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to start this research path")
    }
}

#Preview {
    AskView()
        .frame(width: 600, height: 500)
}
