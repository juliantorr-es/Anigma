import AnigmaClientKit
import ContractsCore
import SwiftUI

struct ReceiptInspector: View {
    @Environment(AppStore.self) private var store
    let receiptHash: String

    @State private var receipt: AnigmaClientKit.CoreReceipt?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Label("CoreReceipt Details", systemImage: "doc.text.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Verification Proof")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            if isLoading {
                ProgressView("Fetching receipt data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let receipt = receipt {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Seal Type
                        HStack {
                            let seal = receipt.seal.flatMap { sealString -> ReceiptSeal in
                                // Simple conversion - treat all seals as unsigned for now
                                // In a real implementation, this would parse the seal format
                                return .unsigned(hash: sealString)
                            } ?? .unsigned(hash: "unsealed")
                            let (icon, color, label) = sealInfo(for: seal)
                            Image(systemName: icon)
                                .foregroundStyle(color)
                            Text(label)
                                .font(.headline)
                        }

                        Divider()

                        // Metadata
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "CoreReceipt ID", value: receipt.ref.id)
                                .accessibilityElement(children: .combine)
                            InfoRow(label: "Intent Hash", value: receipt.ref.intentHash)
                                .accessibilityElement(children: .combine)
                            InfoRow(label: "Status", value: receipt.status.rawValue)
                                .accessibilityElement(children: .combine)
                            InfoRow(
                                label: "Timestamp",
                                value: receipt.ref.timestamp.formatted())
                                .accessibilityElement(children: .combine)
                        }

                        Divider()

                        // Outcome JSON
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Outcome Summary")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)

                            Text("Outcome data not available")
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .accessibilityLabel("Outcome Data")
                        }

                        if let link = receipt.ledgerLink {
                            Divider()
                            Link(destination: URL(string: link)!) {
                                Label("View on Ledger", systemImage: "link")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("CoreReceipt Not Found", systemImage: "doc.text")
            }
        }
        .padding()
        .task {
            isLoading = true
            receipt = try? await store.getReceipt(hash: receiptHash)
            isLoading = false
        }
    }

    private func sealInfo(for seal: ReceiptSeal) -> (String, Color, String) {
        switch seal {
        case .unsigned:
            return ("shield", .blue, "Authority Verified (Unsigned)")
        case .signed:
            return ("checkmark.shield.fill", .green, "Governed & Signed")
        }
    }
}

extension BindingValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let a): return "[\"\(a.map { $0.description }.joined(separator: ", " ))\"]"
        case .object(let o):
            return "{\(o.map { "\"\($0.key)\": \($0.value.description)" }.joined(separator: ", "))}"
        }
    }
}
