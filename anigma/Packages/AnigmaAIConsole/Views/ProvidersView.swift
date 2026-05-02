import AnigmaAgents
import SwiftUI

struct ProvidersView: View {
    let client: AIConsoleClient
    @State private var providers: [AIProvider] = []

    var body: some View {
        List(providers) { provider in
            HStack {
                VStack(alignment: .leading) {
                    Text(provider.name).font(.headline)
                    Text(provider.policyPosture).font(.caption)
                }
                Spacer()
                if provider.isEnabled {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(provider.name), Policy: \(provider.policyPosture)")
            .accessibilityValue(provider.isEnabled ? "Enabled" : "Disabled")
        }
        .accessibilityLabel("AI Providers List")
        .overlay {
            if providers.isEmpty {
                ContentUnavailableView("No Providers Configured", systemImage: "server.rack", description: Text("Add an AI provider to start using agents."))
            }
        }
        .task {
            providers = (try? await client.listProviders()) ?? []
        }
    }
}
