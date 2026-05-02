//
//  AccessControlView.swift
//  AnigmaAppMac
//
//  Access policy and audit UI.
//

import SwiftUI

struct AccessControlView: View {
    let store: AccessumFlowStore
    @State private var showingCreatePolicy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Access Policy & Audit")
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
                    Task { await store.loadPolicies() }
                }
                Button("Load Audit Log") {
                    Task { await store.loadAuditLog() }
                }
                Button("Refresh Flow Status") {
                    Task { await store.refreshFlowStatus() }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await store.loadPolicies()
            await store.refreshFlowStatus()
        }
        .sheet(isPresented: $showingCreatePolicy) {
            CreatePolicyView(store: store)
        }
    }
}

struct CreatePolicyView: View {
    let store: AccessumFlowStore
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
                        await store.createPolicy(name: policyName, rules: [])
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
