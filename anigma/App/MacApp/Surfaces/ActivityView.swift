//
//  ActivityView.swift
//  AnigmaAppMac
//
//  Activity - job progress and history.
//  Bauhaus styling: visible table structure, minimal decoration.
//

import SwiftUI
import AnigmaClientKit

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Set<JobID> = []

    var body: some View {
        Group {
            if store.jobs.isEmpty {
                ActivityEmptyState()
            } else {
                ActivityContent(selection: $selection)
            }
        }
        .navigationTitle("Activity")
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Empty State

struct ActivityEmptyState: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Table Header Structure
            HStack(spacing: 0) {
                ActivityHeader(title: "Status", width: 80)
                ActivityHeader(title: "Job", width: nil)
                ActivityHeader(title: "Evidence", width: 100)
                ActivityHeader(title: "Time", width: 100)
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()
            .accessibilityHidden(true) // Headers in empty state are decorative context

            VStack(spacing: Bauhaus.Grid.x4) {
                Spacer()
                Image(systemName: "clock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Bauhaus.Color.borderStrong)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("No activity recorded")
                        .font(Bauhaus.Font.header)
                        .accessibilityAddTraits(.isHeader)
                    Text("Actions performed will appear here with verification receipts.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Button("Connect Sources") {
                        store.isSourceConnectionPresented = true
                    }
                    .bauhausAccentButton()
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
    }
}

struct ActivityHeader: View {
    let title: String
    let width: CGFloat?

    var body: some View {
        Text(title.uppercased())
            .font(Bauhaus.Font.caption)
            .fontWeight(.bold)
            .foregroundStyle(Bauhaus.Color.textSecondary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, 8)
    }
}

// MARK: - Content

struct ActivityContent: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: Set<JobID>

    var body: some View {
        Table(store.jobs, selection: $selection) {
            TableColumn("Status") { job in
                JobStatusBadge(status: job.status)
            }
            .width(80)

            TableColumn("Job") { job in
                Text(job.name).font(Bauhaus.Font.body)
            }

            TableColumn("Evidence") { job in
                if let hash = job.finalReceiptHash {
                    Text(hash.prefix(8) + "…")
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.accent)
                        .accessibilityLabel("Receipt hash ending in \(hash.suffix(4))")
                } else {
                    Text("Pending").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
            .width(100)
        }
        .listStyle(.inset)
        .onChange(of: selection) { _, newValue in
            if let first = newValue.first {
                store.inspectorSelection = .job(id: first)
            }
        }
    }
}

#Preview {
    ActivityView()
        .frame(width: 700, height: 400)
}
