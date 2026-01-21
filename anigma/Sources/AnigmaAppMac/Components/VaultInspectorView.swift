//
//  VaultInspectorView.swift
//  AnigmaAppMac
//
//  Displays vault statistics and provides verification/GC controls.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct VaultInspectorView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var isVerifying = false
    @State private var isRunningGC = false
    @State private var verificationResult: HarmoniaClient.VaultVerificationResponse?
    @State private var gcResult: HarmoniaClient.VaultGCResponse?
    @State private var errorMessage: String?
    @State private var showGCConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            if let vault = store.vaultStatus {
                statisticsView(vault)
                actionsView
            } else {
                emptyStateView
            }

            if let error = errorMessage {
                errorView(error)
            }

            if let verification = verificationResult {
                verificationResultView(verification)
            }

            if let gc = gcResult {
                gcResultView(gc)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .task {
            if store.vaultNeedsRefresh {
                await store.refreshVaultStatus()
            }
        }
        .confirmationDialog("Run Garbage Collection?", isPresented: $showGCConfirmation) {
            Button("Run GC", role: .destructive) {
                Task { await runGC(dryRun: false) }
            }
            .accessibilityLabel("Start garbage collection")
            Button("Dry Run (Preview)", role: .none) {
                Task { await runGC(dryRun: true) }
            }
            .accessibilityLabel("Run GC simulation")
            Button("Cancel", role: .cancel) { }
                .accessibilityLabel("Cancel action")
        } message: {
            Text("This will remove unused artifacts from the vault. A dry run will show what would be deleted without actually removing anything.")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Vault Inspector")
                .font(Bauhaus.Font.header)

            Spacer()

            Button(action: { Task { await store.refreshVaultStatus() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh vault status")
            .buttonStyle(.borderless)
        }
    }

    private func statisticsView(_ vault: HarmoniaClient.VaultStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            statRow(
                label: "Total Artifacts",
                value: "\(vault.totalArtifacts)",
                icon: "doc.fill"
            )

            statRow(
                label: "Total Size",
                value: formatBytes(vault.totalSizeBytes),
                icon: "internaldrive.fill"
            )

            statRow(
                label: "Health",
                value: vault.health,
                icon: healthIcon(vault.health),
                color: healthColor(vault.health) // OK: Bauhaus
            )

            if let lastCompaction = vault.lastCompaction {
                statRow(
                    label: "Last Compaction",
                    value: formatDate(lastCompaction),
                    icon: "calendar"
                )
            }
        }
    }

    private func statRow(label: String, value: String, icon: String, color: Color? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color ?? Bauhaus.Color.textSecondary)
                .frame(width: Bauhaus.Grid.x2)

            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Spacer()

            Text(value)
                .font(Bauhaus.Font.mono)
                .foregroundStyle(color ?? Bauhaus.Color.textPrimary)
        }
    }

    private var actionsView: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Button(action: { Task { await verifyVault() } }) {
                Label("Verify", systemImage: "checkmark.seal.fill")
            }
            .accessibilityLabel("Verify vault integrity")
            .secondaryButtonStyle()
            .disabled(isVerifying)

            if isVerifying {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: { showGCConfirmation = true }) {
                Label("GC", systemImage: "trash.fill")
            }
            .accessibilityLabel("Garbage collection options")
            .destructiveButtonStyle()
            .disabled(isRunningGC)

            if isRunningGC {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            ProgressView()
                .controlSize(.small)

            Text("Loading vault status...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
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

    private func verificationResultView(_ result: HarmoniaClient.VaultVerificationResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Image(systemName: result.valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.valid ? Bauhaus.Color.success : Bauhaus.Color.error)

                Text(result.valid ? "Verification Passed" : "Verification Failed")
                    .font(Bauhaus.Font.subHeader)
            }

            if !result.errors.isEmpty {
                ForEach(result.errors, id: \.self) { error in
                    Label(error, systemImage: "xmark.circle")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.error)
                }
            }

            if !result.warnings.isEmpty {
                ForEach(result.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.warning)
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background((result.valid ? Bauhaus.Color.success : Bauhaus.Color.error).opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func gcResultView(_ result: HarmoniaClient.VaultGCResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Bauhaus.Color.success)

                Text(result.dryRun ? "GC Dry Run Complete" : "GC Complete")
                    .font(Bauhaus.Font.subHeader)
            }

            statRow(
                label: result.dryRun ? "Would Remove" : "Removed",
                value: "\(result.removedArtifacts) artifacts",
                icon: "trash"
            )

            statRow(
                label: result.dryRun ? "Would Free" : "Freed",
                value: formatBytes(result.freedBytes),
                icon: "internaldrive"
            )
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.success.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func verifyVault() async {
        isVerifying = true
        errorMessage = nil
        verificationResult = nil

        do {
            verificationResult = try await store.verifyVault()
        } catch {
            errorMessage = "Verification failed: \(error.localizedDescription)"
        }

        isVerifying = false
    }

    private func runGC(dryRun: Bool) async {
        isRunningGC = true
        errorMessage = nil
        gcResult = nil

        do {
            gcResult = try await store.runVaultGC(dryRun: dryRun)
        } catch {
            errorMessage = "GC failed: \(error.localizedDescription)"
        }

        isRunningGC = false
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func healthIcon(_ health: String) -> String {
        switch health.lowercased() {
        case "good", "healthy": return "heart.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "critical", "error": return "heart.slash.fill"
        default: return "heart"
        }
    }

    private func healthColor(_ health: String) -> Color { // OK: Bauhaus
        switch health.lowercased() {
        case "good", "healthy": return Bauhaus.Color.success
        case "warning": return Bauhaus.Color.warning
        case "critical", "error": return Bauhaus.Color.error
        default: return Bauhaus.Color.textSecondary
        }
    }
}
