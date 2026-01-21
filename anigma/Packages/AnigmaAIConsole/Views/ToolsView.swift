import AnigmaAgents
import SwiftUI

struct ToolsView: View {
    let client: AIConsoleClient
    @State private var tools: [AITool] = []

    var body: some View {
        List(tools) { tool in
            HStack {
                VStack(alignment: .leading) {
                    Text(tool.name).font(.headline)
                    Text(tool.path).font(.caption)
                }
                Spacer()
                if tool.isApproved {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .accessibilityLabel("Approved")
                } else {
                    Button("Approve") {
                        Task {
                            try? await client.approveTool(id: tool.id)
                        }
                    }
                    .accessibilityLabel("Approve \(tool.name)")
                }
            }
            .accessibilityElement(children: .contain)
        }
        .overlay {
            if tools.isEmpty {
                ContentUnavailableView("No Tools Available", systemImage: "hammer", description: Text("Tools will appear here when registered by agents."))
            }
        }
        .task {
            tools = (try? await client.listTools()) ?? []
        }
    }
}
