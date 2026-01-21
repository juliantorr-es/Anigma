import SwiftUI
import ExportCore

public struct PreviewView: View {
    @State private var isDraft: Bool = true

    public init() {}

    public var body: some View {
        VStack {
            Picker("Mode", selection: $isDraft) {
                Text("Draft").tag(true)
                Text("Final").tag(false)
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityLabel("Preview Mode")
            .accessibilityHint("Toggle between draft and final preview")

            Spacer()

            Text("Preview Placeholder")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
}
