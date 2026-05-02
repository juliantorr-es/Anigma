import ContractsCore
import SwiftUI

struct ReceiptChainView: View {
    let jobID: String
    let headReceiptHash: String
    @Environment(AppStore.self) private var store
    @State private var receipts: [Receipt] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isLoading {
                ProgressView("Walking cryptographic chain...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                ContentUnavailableView(
                    "Failed to load chain", systemImage: "xmark.shield", description: Text(error))
            } else {
                chainList
            }
        }
        .padding()
        .task {
            await loadChain()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deterministic Chain of Truth")
                .font(.headline)
            Text("Verified sequence of cryptographic receipts proving this job's outcome.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var chainList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(receipts.enumerated()), id: \.element.ref.id) { index, receipt in
                    ReceiptNodeView(receipt: receipt, isLink: index < receipts.count - 1)
                }
            }
        }
    }

    private func loadChain() async {
        isLoading = true
        receipts = []
        var currentHash: String? = headReceiptHash

        do {
            while let hash = currentHash {
                if let receipt = try await store.getReceipt(hash: hash) {
                    receipts.append(receipt)
                    currentHash = receipt.previousReceiptHash
                } else {
                    currentHash = nil
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct ReceiptNodeView: View {
    let receipt: Receipt
    let isLink: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                statusIcon
                if isLink {
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(receipt.ref.id)
                        .font(.monospaced(.body)())
                        .fontWeight(.bold)
                    Spacer()
                    Text(formatDate(receipt.ref.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(receipt.status.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(receipt.status == .success ? .green : .red)
                }

                if let ledger = receipt.ledgerLink {
                    Link(destination: URL(string: ledger)!) {
                        Label("View on Ledger", systemImage: "link")
                            .font(.caption)
                    }
                    .accessibilityLabel("View receipt on public ledger")
                }
            }
            .padding(.bottom, isLink ? 20 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Receipt \(receipt.ref.id). Status: \(receipt.status.rawValue). Time: \(formatDate(receipt.ref.timestamp)).")
        .accessibilityAction(named: "View on Ledger") {
            if let ledger = receipt.ledgerLink, let url = URL(string: ledger) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(receipt.status == .success ? .green : .red)
                .frame(width: 12, height: 12)

            Circle()
                .strokeBorder(.background, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
        .padding(.top, 4)
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
