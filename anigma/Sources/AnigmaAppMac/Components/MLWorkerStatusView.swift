//
//  MLWorkerStatusView.swift
//  AnigmaAppMac
//
//  Display ML Worker installation status and capabilities.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct MLWorkerStatusView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let status = store.mlWorkerStatus {
                statusDetailsView(status)
            } else if isRefreshing {
                loadingView
            } else {
                emptyStateView
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            await refreshStatus()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("ML Worker Status")
                .font(Bauhaus.Font.header)

            Spacer()

            Button(action: { Task { await refreshStatus() } }) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .accessibilityLabel("Refresh worker status")
            .buttonStyle(.borderless)
            .disabled(isRefreshing)
        }
    }

    private func statusDetailsView(_ status: MLWorkerClient.WorkerStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            // Installation status
            HStack {
                Circle()
                    .fill(status.installed ? Bauhaus.Color.success : Bauhaus.Color.error)
                    .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)

                Text(status.installed ? "Installed" : "Not Installed")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(status.installed ? Bauhaus.Color.success : Bauhaus.Color.error)
            }

            if status.installed {
                Divider()

                // Binary path
                infoRow(label: "Binary Path", value: status.binaryPath)

                // Version
                if let version = status.version {
                    infoRow(label: "Version", value: version)
                }

                Divider()

                // Available engines
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Available Engines")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    HStack(spacing: Bauhaus.Grid.x2) {
                        ForEach(status.availableEngines, id: \.self) { engine in
                            engineBadge(engine)
                        }
                    }
                }
            } else {
                Divider()

                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("ML Worker is not installed")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)

                    Text("Install ml-worker to enable ML task processing")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: 100, alignment: .leading) // OK: Fixed label width

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func engineBadge(_ engine: String) -> some View {
        Text(engine)
            .font(Bauhaus.Font.caption)
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, Bauhaus.Grid.unit)
            .background(Bauhaus.Color.accent.opacity(0.1))
            .foregroundStyle(Bauhaus.Color.accent)
            .cornerRadius(Bauhaus.Grid.unit)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                    .stroke(Bauhaus.Color.accent.opacity(0.3), lineWidth: 1)
            )
    }

    private var loadingView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
                .controlSize(.small)

            Text("Checking ML Worker...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "brain")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("ML Worker status unknown")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Button("Check Status") {
                Task { await refreshStatus() }
            }
            .accessibilityLabel("Check worker status")
            .buttonStyle(.borderedProminent)
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

    private func refreshStatus() async {
        isRefreshing = true
        errorMessage = nil

        await store.loadMLWorkerStatus()

        isRefreshing = false
    }
}

#Preview {
    MLWorkerStatusView()
        .frame(width: 500, height: 400) // OK: Preview sizing
        .environment(AppStore())
}
