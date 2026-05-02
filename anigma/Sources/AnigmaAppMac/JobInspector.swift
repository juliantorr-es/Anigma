//
//  JobInspector.swift
//  AnigmaAppMac
//
//  Inspector panel for job details with receipt verification status.
//

import AnigmaClientKit
import ContractsCore
import SwiftUI

struct JobInspector: View {
    @Environment(AppStore.self) private var store
    let jobId: String

    @State private var showingCancelConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLogs = false
    @State private var isEvaluating = false
    @State private var cancelEvaluation: IntentEvaluation?
    @State private var deleteEvaluation: IntentEvaluation?

    private var job: AnigmaClientKit.JobSummary? {
        store.jobs.first { $0.id == jobId }
    }

    var body: some View {
        if let job = job {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Job", systemImage: "gearshape.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(job.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                }

                Divider()

                // Trust Status
                GroupBox {
                    HStack {
                        Image(
                            systemName: job.isTrusted
                                ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                        )
                        .foregroundStyle(job.isTrusted ? .green : .orange)
                        .font(.title3)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.isTrusted ? "Verified Truth" : "Unverified Output")
                                .font(.headline)
                            Text(
                                job.isTrusted
                                    ? "This job's outcome is cryptographically verified."
                                    : "Verification is required to trust this output."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(job.isTrusted ? "Verified Truth: Cryptographically verified." : "Unverified Output: Verification required.")
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Job ID", value: job.id)
                    InfoRow(label: "Status", value: job.status)
                    InfoRow(label: "Trusted", value: job.isTrusted ? "Yes" : "No")
                    if let hash = job.finalReceiptHash {
                        InfoRow(label: "CoreReceipt", value: hash)
                    }
                }

                Divider()

                // Outputs Section (Zero-Trust Enforced)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Outputs")
                        .font(.headline)

                    if job.isTrusted {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("analysis_result.json", systemImage: "doc.text")
                                .font(.body)
                            Text("Size: 42 KB • Type: application/json")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        TrustWarningView(
                            actionLabel: job.status.uppercased() == "SUCCEEDED"
                                ? "Verify Now" : nil
                        )                            {
                                Task {
                                    await store.verifyJob(id: job.id)
                                }
                            }
                    }
                }

                if let headHash = job.finalReceiptHash {
                    Divider()
                    ReceiptChainView(jobID: job.id, headReceiptHash: headHash)
                }

                Divider()

                // Actions
                VStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await store.verifyJob(id: job.id)
                        }
                    }) {
                        Label("Verify Determinism", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(job.status.uppercased() != "SUCCEEDED")

                    Button(action: { showingLogs = true }) {
                        Label("View Logs", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(job.status.uppercased() == "QUEUED")

                    if job.status.uppercased() == "RUNNING" || job.status.uppercased() == "QUEUED" {
                        Button(action: {
                            showingCancelConfirmation = true
                        }) {
                            Label("Cancel Job", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(cancelEvaluation != .allowed && !isEvaluating)
                        .confirmationDialog(
                            "Cancel Job",
                            isPresented: $showingCancelConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Cancel Job", role: .destructive) {
                                Task { await store.cancelJob(id: job.id) }
                            }
                            Button("Keep Running", role: .cancel) {}
                        } message: {
                            Text(
                                "Are you sure you want to cancel this running job? This action cannot be undone."
                            )
                        }
                    } else {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete Job", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(deleteEvaluation != .allowed && !isEvaluating)
                        .confirmationDialog(
                            "Delete Job",
                            isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Job", role: .destructive) {
                                Task { await store.deleteJob(id: job.id) }
                            }
                            Button("Keep Job", role: .cancel) {}
                        } message: {
                            Text(
                                "Are you sure you want to delete this job record? This will remove all local history of this job."
                            )
                        }
                    }

                    if job.status.uppercased() == "RUNNING",
                       let evaluation = cancelEvaluation,
                       case .denied(let reason) = evaluation {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if ["SUCCEEDED", "FAILED", "CANCELED"].contains(job.status.uppercased()),
                       let evaluation = deleteEvaluation,
                       case .denied(let reason) = evaluation {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .task(id: jobId) {
                await evaluateActions()
            }
            .sheet(isPresented: $showingLogs) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Job Logs: \(job.name)").font(Bauhaus.Font.header)
                        Spacer()
                        Button("Done") { showingLogs = false }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Bauhaus.Color.surface)

                    Divider()

                    ConsoleView(logs: store.consoleLogs)
                }
                .frame(minWidth: 600, minHeight: 400)
                .background(Bauhaus.Color.background)
            }
        } else {
            ContentUnavailableView("Job Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    private func evaluateActions() async {
        guard let job = job else { return }
        isEvaluating = true

        if job.status.uppercased() == "RUNNING" || job.status.uppercased() == "QUEUED" {
            cancelEvaluation = await store.evaluateAction(
                action: "job.cancel",
                parameters: ["jobId": .string(jobId)]
            )
        }

        if ["SUCCEEDED", "FAILED", "CANCELED"].contains(job.status.uppercased()) {
            deleteEvaluation = await store.evaluateAction(
                action: "job.delete",
                parameters: ["jobId": .string(jobId)]
            )
        }

        isEvaluating = false
    }

    private func statusColor(for status: String) -> Color {
        switch status.uppercased() {
        case "SUCCEEDED": return .green
        case "FAILED": return .red
        case "RUNNING", "QUEUED": return .blue
        case "CANCELED": return .orange
        default: return .gray
        }
    }
}
