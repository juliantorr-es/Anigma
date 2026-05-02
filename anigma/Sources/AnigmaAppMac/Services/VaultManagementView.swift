//
//  VaultManagementView.swift
//  AnigmaAppMac
//
//  UI for managing the evidence vault and performing maintenance.
//

import SwiftUI
import HarmoniaV2Contracts

struct VaultManagementView: View {
    @ObservedObject var model: AppModel
    @State private var isVerifying = false
    @State private var isCleaning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerView
            
            if let status = model.vaultStatus {
                vaultStatusCard(status: status)
            } else {
                loadingCard
            }
            
            maintenanceActionsCard
            
            Spacer()
        }
        .padding(24)
        .background(Bauhaus.Color.background)
        .task {
            await model.refreshVaultStatus()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Evidence Vault")
                .font(.title)
                .fontWeight(.bold)
            Text("Cryptographic evidence of all governed operations is stored here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading vault status...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Bauhaus.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }

    private func vaultStatusCard(status: HarmoniaClient.VaultStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Vault Integrity", systemImage: "shield.checkered")
                    .font(.headline)
                Spacer()
                statusBadge(isHealthy: status.isHealthy)
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    statRow(label: "Status", value: status.isHealthy ? "Healthy" : "Needs Attention")
                    statRow(label: "Disk Usage", value: status.diskUsage)
                }
                GridRow {
                    statRow(label: "Last Verification", value: status.lastVerifiedAt?.formatted(.relative(presentation: .named)) ?? "Never")
                    statRow(label: "Head Hash", value: status.headHash.prefix(8) + "...", isMono: true)
                }
            }
        }
        .padding(20)
        .background(Bauhaus.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }

    private var maintenanceActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maintenance")
                .font(.headline)
            
            Text("Regular maintenance ensures the vault remains healthy and efficient.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    Task {
                        isVerifying = true
                        _ = try? await model.verifyVault()
                        isVerifying = false
                    }
                } label: {
                    HStack {
                        if isVerifying {
                            ProgressView().controlSize(.small)
                        }
                        Label("Verify Integrity", systemImage: "checkmark.shield")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isVerifying || isCleaning)

                Button {
                    Task {
                        isCleaning = true
                        _ = try? await model.runVaultGC()
                        isCleaning = false
                    }
                } label: {
                    HStack {
                        if isCleaning {
                            ProgressView().controlSize(.small)
                        }
                        Label("Garbage Collection", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isVerifying || isCleaning)
                
                Spacer()
                
                Button {
                    Task { await model.refreshVaultStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh Status")
            }
        }
        .padding(20)
        .background(Bauhaus.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }

    private func statusBadge(isHealthy: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isHealthy ? .green : .red)
                .frame(width: 8, height: 8)
            Text(isHealthy ? "Healthy" : "Needs Attention")
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHealthy ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(Capsule())
    }

    private func statRow(label: String, value: String, isMono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospaced(isMono)
        }
    }
}
