//
//  InspectorPane.swift
//  AnigmaAppMac
//
//  Truth Panel - Context + Receipts.
//  Universal pattern: what is selected + what Anigma knows + sources + receipts.
//

import SwiftUI
import AnigmaClientKit

struct InspectorPane: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header - Context Title
            HStack {
                Text(contextTitle.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                Spacer()
                Button(action: { store.inspectorSelection = nil }) {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, 10)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Truth Tabs
            HStack(spacing: 0) {
                TruthTab(title: "Context", isSelected: selectedTab == 0) { selectedTab = 0 }
                TruthTab(title: "Evidence", isSelected: selectedTab == 1) { selectedTab = 1 }
                TruthTab(title: "Sources", isSelected: selectedTab == 2) { selectedTab = 2 }
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                    if let selection = store.inspectorSelection {
                        switch selection {
                        case .artifact(let id):
                            ArtifactTruthView(id: id, tab: selectedTab)
                        case .job(let id):
                            JobTruthView(id: id, tab: selectedTab)
                        case .receipt(let hash):
                            ReceiptTruthView(hash: hash, tab: selectedTab)
                        case .entity(let id):
                            EntityTruthView(id: id, tab: selectedTab)
                        }
                    } else {
                        EmptyTruthView()
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }
        }
        .background(Bauhaus.Color.surface)
    }

    private var contextTitle: String {
        switch store.inspectorSelection {
        case .artifact(let id):
            return store.artifacts.first { $0.id == id }?.name ?? "Artifact"
        case .job(let id):
            return store.jobs.first { $0.id == id }?.name ?? "Job"
        case .receipt(let hash):
            return "Receipt \(hash.prefix(8))"
        case .entity(let id):
            return "Entity \(id)"
        case nil:
            return "System Context"
        }
    }
}

// MARK: - Detail Views

struct ArtifactTruthView: View {
    let id: ArtifactID
    let tab: Int
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            if tab == 0 { // Context
                TruthInfoRow(label: "Type", value: "Local PDF")
                TruthInfoRow(label: "Status", value: "Local Only", accent: Bauhaus.Color.accent)
                TruthInfoRow(label: "Ingested", value: "2026-01-04")

                Divider().padding(.vertical, 4)

                Text("Anigma identifies 4 key entities and 2 primary claims in this document.")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            } else if tab == 1 { // Evidence
                Label("Verified with local hash", systemImage: "checkmark.shield.fill")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.accent)

                Text("SHA-256: 8a3f...2e91")
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            } else { // Sources
                Text("Original file on local disk.")
                    .font(Bauhaus.Font.body)
                Text("/Users/user/Documents/syllabus.pdf")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }
        }
    }
}

struct JobTruthView: View {
    let id: JobID
    let tab: Int
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            if let job = store.jobs.first(where: { $0.id == id }) {
                if tab == 0 { // Context
                    TruthInfoRow(label: "Action", value: job.name)
                    TruthInfoRow(label: "Status", value: job.status, accent: job.status == "SUCCEEDED" ? Bauhaus.Color.accent : .blue)
                } else if tab == 1 { // Evidence
                    if let hash = job.finalReceiptHash {
                        Text("receipt-hash: \(hash)").font(Bauhaus.Font.mono)
                    } else {
                        Text("Evidence pending execution.").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                } else { // Sources
                    Text("Executed on local harmonia host.")
                        .font(Bauhaus.Font.body)
                }
            }
        }
    }
}

struct ReceiptTruthView: View {
    let hash: String
    let tab: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Receipt Detail").font(Bauhaus.Font.header)
            Text(hash).font(Bauhaus.Font.mono).foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }
}

struct EntityTruthView: View {
    let id: String
    let tab: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            if tab == 0 { // Context
                TruthInfoRow(label: "Entity", value: id)
                TruthInfoRow(label: "Type", value: "Governed Object")

                Divider().padding(.vertical, 4)

                Text("This entity is tracked across multiple documents.")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            } else if tab == 1 { // Evidence
                 Label("Graph Connected", systemImage: "network")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.accent)
            }
        }
    }
}

struct EmptyTruthView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 32))
                .foregroundStyle(Bauhaus.Color.borderStrong)
            Text("Select an item to view Truth Context.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TruthInfoRow: View {
    let label: String
    let value: String
    var accent: SwiftUI.Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textTertiary)
            Text(value)
                .font(Bauhaus.Font.body)
                .foregroundStyle(accent ?? Bauhaus.Color.textPrimary)
        }
    }
}

#Preview {
    InspectorPane()
        .frame(width: 320, height: 600)
}
