import SwiftUI
import ExportCore

public struct AgentLaneView: View {
    @State private var prompt: String = ""
    @State private var proposals: [String] = [] // Placeholder for proposals

    public init() {}

    public var body: some View {
        VStack {
            List(proposals, id: \.self) { proposal in
                Text(proposal)
            }

            HStack {
                TextField("Ask agent to tweak layout...", text: $prompt)
                    .accessibilityLabel("Agent Prompt")
                Button("Ask") {
                    proposals.append("Proposed change: \(prompt)")
                    prompt = ""
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}
