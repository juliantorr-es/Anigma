import SwiftUI
import DataCore
import RendererKit

public struct TransformPreviewView: View {
    let changeArtifact: ChangeArtifact

    public init(changeArtifact: ChangeArtifact) {
        self.changeArtifact = changeArtifact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transform Preview")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack {
                StatView(label: "Records Affected", value: "\(changeArtifact.recordsAffected)")
                StatView(label: "Columns Changed", value: "\(changeArtifact.columnsChanged.count)")
            }

            Divider()

            Text("Diff Summary")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            Text(changeArtifact.diffSummary)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            Spacer()
        }
        .padding()
    }
}

struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
    }
}
