//
//  PreflightGate.swift
//  AnigmaAppMac
//
//  Governed Preflight Gate for Agent runs.
//  Bauhaus: Explicit, audit-ready, gated.
//

import SwiftUI

struct PreflightGate: View {
    @Environment(AppStore.self) private var store
    let workspace: RepoWorkspace
    let profile: AgentProfile
    let command: String

    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 24))
                    .foregroundStyle(Bauhaus.Color.accent)
                VStack(alignment: .leading) {
                    Text("Preflight Gate").font(Bauhaus.Font.header)
                    Text("Audit and authorize the upcoming governed run.").font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.textSecondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark").foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Agent Profile
                    PreflightSection(title: "AGENT PROFILE") {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.shield.check.fill")
                            Text(profile.name).font(Bauhaus.Font.body).fontWeight(.bold)
                            Spacer()
                            Text(profile.providerId).font(Bauhaus.Font.mono).font(.system(size: 10))
                        }
                    }

                    // Scope & Sandbox
                    PreflightSection(title: "SCOPE & SANDBOX") {
                        VStack(alignment: .leading, spacing: 8) {
                            PreflightRow(icon: "folder.fill", label: "Working Dir", value: workspace.name)
                            PreflightRow(icon: "arrow.triangle.pull", label: "Branch", value: workspace.gitState.branch)
                            PreflightRow(icon: "scope", label: "Sandbox", value: workspace.sandboxURL?.lastPathComponent ?? "Volatile Worktree")
                        }
                    }

                    // Command & Context
                    PreflightSection(title: "INTENT") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(command)
                                .font(Bauhaus.Font.mono)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)

                            HStack {
                                Image(systemName: "doc.on.doc.fill")
                                Text("6 files in context bundle").font(Bauhaus.Font.caption)
                            }
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }

                    // Governance Policy
                    PreflightSection(title: "GOVERNANCE POSTURE") {
                        VStack(alignment: .leading, spacing: 10) {
                            PolicyRow(icon: "network.badge.shield.half.filled", label: "Network", value: profile.networkStance.rawValue, isWarning: profile.networkStance == .open)
                            PolicyRow(icon: "cpu", label: "CPU Budget", value: "\(Int(workspace.resourceBudget.cpuLimit * 100))%", isWarning: false)
                            PolicyRow(icon: "timer", label: "Duration", value: "\(workspace.resourceBudget.wallClockLimitSeconds)s", isWarning: false)
                            PolicyRow(icon: "pencil.and.outline", label: "Write Stance", value: "Sandbox Patch (No Direct Writes)", isWarning: false)
                        }
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)

                Spacer()

                Button("Authorize & Run") {
                    onConfirm()
                }
                .bauhausAccentButton()
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)
        }
        .frame(width: 500, height: 650)
        .background(Bauhaus.Color.background)
    }
}

private struct PreflightSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textTertiary)
            content
        }
    }
}

private struct PreflightRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 16)
            Text(label).foregroundStyle(Bauhaus.Color.textSecondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(Bauhaus.Font.body)
    }
}

private struct PolicyRow: View {
    let icon: String
    let label: String
    let value: String
    let isWarning: Bool

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 16)
            Text(label).foregroundStyle(Bauhaus.Color.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                if isWarning {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Text(value).fontWeight(.bold).foregroundStyle(isWarning ? .orange : Bauhaus.Color.accent)
            }
        }
        .font(Bauhaus.Font.body)
    }
}
