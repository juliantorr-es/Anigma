//
//  AccessControlView.swift
//  AnigmaAppMac
//
//  Access control and flow management UI.
//

import SwiftUI

struct AccessControlView: View {
    @Environment(AppStore.self) private var store
    @State private var showingCreatePolicy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Access Control & Flow Management")
                    .font(.headline)
                Spacer()
                Button("Create Policy") {
                    showingCreatePolicy = true
                }
                .buttonStyle(.borderedProminent)
            }

            if let flowStatus = store.flowStatus {
                HStack {
                    Label("\(flowStatus.activeRules) active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(flowStatus.blockedFlows) blocked", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }

            List {
                Section("Policies") {
                    ForEach(store.accessPolicies) { policy in
                        VStack(alignment: .leading) {
                            Text(policy.name).font(.headline)
                            Text("\(policy.rulesCount) rules").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recent Access Events") {
                    ForEach(store.accessAuditLog.prefix(10)) { entry in
                        HStack {
                            Image(systemName: entry.result == "allowed" ? "checkmark.shield" : "xmark.shield")
                                .foregroundStyle(entry.result == "allowed" ? .green : .red)
                            VStack(alignment: .leading) {
                                Text("\(entry.actor) → \(entry.resource)")
                                    .font(.caption)
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Load Policies") {
                    Task { await store.loadAccessPolicies() }
                }
                Button("Load Audit Log") {
                    Task { await store.loadAccessAuditLog() }
                }
                Button("Refresh Flow Status") {
                    Task { await store.refreshFlowStatus() }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await store.loadAccessPolicies()
            await store.refreshFlowStatus()
        }
        .sheet(isPresented: $showingCreatePolicy) {
            CreatePolicyView()
        }
    }
}

struct CreatePolicyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var policyName = ""

    var body: some View {
        VStack {
            Form {
                TextField("Policy Name", text: $policyName)
            }
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") {
                    Task {
                        await store.createAccessPolicy(name: policyName, rules: [])
                        dismiss()
                    }
                }
                .disabled(policyName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
