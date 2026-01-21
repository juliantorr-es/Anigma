import AnigmaAgents
import SwiftUI

public struct AIConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ConsoleTab = .models
    private let client: AIConsoleClient

    public init(client: AIConsoleClient) {
        self.client = client
    }

    public enum ConsoleTab: String, CaseIterable, Identifiable {
        case models = "Models"
        case providers = "Providers"
        case tools = "Tools"
        case benchmarks = "Benchmarks"

        public var id: String { rawValue }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Console").font(.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding()

            Picker("Tab", selection: $selectedTab) {
                ForEach(ConsoleTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityLabel("Console Section")

            switch selectedTab {
            case .models:
                ModelsView(client: client)
            case .providers:
                ProvidersView(client: client)
            case .tools:
                ToolsView(client: client)
            case .benchmarks:
                BenchmarksView(client: client)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
