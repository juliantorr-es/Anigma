//
//  DoctrinePackManagerView.swift
//  AnigmaAppMac
//
//  Manage doctrine packs - enable, disable, view details.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct DoctrinePackManagerView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var selectedPack: DoctrineClient.PacksResponse.Pack?
    @State private var packDetail: DoctrineClient.PackDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let packs = store.doctrinePacks {
                packsListView(packs)
            } else if isLoading {
                loadingView
            } else {
                emptyStateView
            }

            if let detail = packDetail {
                Divider()
                packDetailView(detail)
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            await loadPacks()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Doctrine Packs")
                .font(Bauhaus.Font.header)

            Spacer()

            if let packs = store.doctrinePacks {
                Text("\(packs.totalCount) packs")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Button(action: { Task { await loadPacks() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh packs list")
            .buttonStyle(.borderless)
            .disabled(isLoading)
        }
    }

    private func packsListView(_ packs: DoctrineClient.PacksResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text("Available Packs")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                let enabledCount = packs.packs.filter { $0.enabled }.count
                Text("\(enabledCount) enabled")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.accent)
            }

            ScrollView {
                LazyVStack(spacing: Bauhaus.Grid.x2) {
                    ForEach(packs.packs) { pack in
                        packRow(pack)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectPack(pack)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("View details for \(pack.name)")
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    private func packRow(_ pack: DoctrineClient.PacksResponse.Pack) -> some View {
        let isSelected = selectedPack?.id == pack.id

        return HStack(spacing: Bauhaus.Grid.x2) {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                HStack {
                    Text(pack.name)
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textPrimary)

                    Text("v\(pack.version)")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Spacer()

                    if pack.enabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Bauhaus.Color.success)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                }

                HStack {
                    Label(pack.domain, systemImage: "tag")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Text("•")
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Text("\(pack.ruleCount) rules")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }

            Toggle("", isOn: .constant(pack.enabled))
                .accessibilityLabel("\(pack.name) status")
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(true) // Read-only, use buttons in detail view
        }
        .padding(Bauhaus.Grid.x2)
        .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                .stroke(isSelected ? Bauhaus.Color.accent : Color.clear, lineWidth: 1)
        )
    }

    private func packDetailView(_ detail: DoctrineClient.PackDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text(detail.name)
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                if detail.enabled {
                    Button(action: { Task { await disablePack(detail.id) } }) {
                        Label("Disable", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Disable \(detail.name)")
                    .secondaryButtonStyle()
                } else {
                    Button(action: { Task { await enablePack(detail.id) } }) {
                        Label("Enable", systemImage: "checkmark.circle")
                    }
                    .accessibilityLabel("Enable \(detail.name)")
                    .primaryButtonStyle()
                }
            }

            Text(detail.description)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Divider()

            detailRow(label: "Domain", value: detail.domain)
            detailRow(label: "Version", value: detail.version)
            detailRow(label: "Source", value: detail.canonicalSource)
            detailRow(label: "Rules", value: "\(detail.rules.count)")
            detailRow(label: "Principles", value: "\(detail.principles.count)")

            if !detail.rules.isEmpty {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Included Rules")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Bauhaus.Grid.unit / 2) {
                            ForEach(detail.rules, id: \.self) { ruleId in
                                Text("• \(ruleId)")
                                    .font(Bauhaus.Font.mono)
                                    .foregroundStyle(Bauhaus.Color.textTertiary)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: 80, alignment: .leading) // OK: Fixed label width

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
                .controlSize(.small)

            Text("Loading packs...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("No packs available")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Button("Load Packs") {
                Task { await loadPacks() }
            }
            .accessibilityLabel("Import doctrine packs")
            .primaryButtonStyle()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.error)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.error.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func loadPacks() async {
        isLoading = true
        errorMessage = nil

        await store.loadDoctrinePacks()

        if store.doctrinePacks == nil {
            errorMessage = "Failed to load packs. Check that doctrine is installed."
        }

        isLoading = false
    }

    private func selectPack(_ pack: DoctrineClient.PacksResponse.Pack) {
        selectedPack = pack

        Task {
            do {
                if let client = store.doctrineClient {
                    packDetail = try await client.getPack(id: pack.id)
                }
            } catch {
                errorMessage = "Failed to load pack details: \(error.localizedDescription)"
            }
        }
    }

    private func enablePack(_ packId: String) async {
        do {
            try await store.enableDoctrinePack(id: packId)

            // Refresh detail
            if let pack = selectedPack, let client = store.doctrineClient {
                packDetail = try await client.getPack(id: pack.id)
            }

            store.showToast(
                title: "Pack Enabled",
                subtitle: "Doctrine pack is now active",
                icon: "checkmark.circle.fill"
            )
        } catch {
            errorMessage = "Failed to enable pack: \(error.localizedDescription)"
        }
    }

    private func disablePack(_ packId: String) async {
        do {
            try await store.disableDoctrinePack(id: packId)

            // Refresh detail
            if let pack = selectedPack, let client = store.doctrineClient {
                packDetail = try await client.getPack(id: pack.id)
            }

            store.showToast(
                title: "Pack Disabled",
                subtitle: "Doctrine pack is now inactive",
                icon: "xmark.circle"
            )
        } catch {
            errorMessage = "Failed to disable pack: \(error.localizedDescription)"
        }
    }
}
