//
//  CathedralVisualizer.swift
//  AnigmaAppMac
//
//  High-transparency UI for inspecting the evidence chain (Cathedral).
//

import SwiftUI
import AnigmaCore

@MainActor
public class CathedralViewModel: ObservableObject {
    @Published public var bundles: [EvidenceBundle] = []
    @Published public var verificationResults: [ReceiptID: VerificationResult] = [:]
    @Published public var isVerifying: Bool = false

    private let runtime: RuntimeServices

    public init(runtime: RuntimeServices) {
        self.runtime = runtime
    }

    public func refresh() async {
        do {
            let filter = EvidenceFilter()
            self.bundles = try await runtime.evidence.query(filter: filter, principal: Principal(id: "admin", displayName: "Administrator"))
        } catch {
            print("Cathedral: Refresh failed - \(error)")
        }
    }

    public func verifyAll() async {
        isVerifying = true
        defer { isVerifying = false }

        for bundle in bundles {
            if let result = try? await runtime.evidence.verify(receiptId: bundle.id) {
                verificationResults[bundle.id] = result
            }
        }
    }
}

public struct CathedralVisualizer: View {
    @ObservedObject var viewModel: CathedralViewModel

    public init(viewModel: CathedralViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List(viewModel.bundles) { bundle in
                ReceiptRow(
                    receipt: bundle.receipt,
                    verification: viewModel.verificationResults[bundle.id]
                )
            }
            .navigationTitle("Evidence Chain")
            .refreshable {
                await viewModel.refresh()
            }
            .toolbar {
                Button(action: { Task { await viewModel.verifyAll() } }) { // Toolbar ButtonStyle
                    if viewModel.isVerifying {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Verify Chain", systemImage: "checkmark.seal")
                    }
                }
                .accessibilityLabel("Verify evidence chain")
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

struct ReceiptRow: View {
    let receipt: CoreReceipt
    let verification: VerificationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Text(receipt.operationType)
                    .font(Bauhaus.Font.subHeader)
                Spacer()
                if let v = verification {
                    Image(systemName: v.isValid ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(v.isValid ? Bauhaus.Color.success : Bauhaus.Color.error)
                }
                StatusBadge(outcome: receipt.outcome)
            }

            Text("Principal: \(receipt.principal.displayName)")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("ID: \(String(receipt.id.raw.prefix(12)))...")
                .font(Bauhaus.Font.monoMicro)
                .padding(Bauhaus.Grid.unit / 2)
                .background(Bauhaus.Color.surface)
                .cornerRadius(Bauhaus.Grid.unit / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: Bauhaus.Grid.unit / 2)
                        .stroke(Bauhaus.Color.border, lineWidth: 0.5)
                )

            if let summary = receipt.summary {
                Text(summary)
                    .font(Bauhaus.Font.body)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Bauhaus.Grid.unit / 2)
    }
}

struct StatusBadge: View {
    let outcome: OperationOutcome

    var body: some View {
        Text(outcome.rawValue.uppercased())
            .font(Bauhaus.Font.micro)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(outcome == .success ? Bauhaus.Color.success.opacity(0.2) : Bauhaus.Color.error.opacity(0.2))
            .foregroundStyle(outcome == .success ? Bauhaus.Color.success : Bauhaus.Color.error)
            .cornerRadius(Bauhaus.Grid.unit / 2)
    }
}
