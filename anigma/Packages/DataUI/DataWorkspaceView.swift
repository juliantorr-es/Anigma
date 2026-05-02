import SwiftUI
import DataCore
import DataEngine
import RendererKit

public struct DataWorkspaceView: View {
    @Binding var selectionId: String?
    @State private var selectedViewMode: ViewMode = .grid
    @State private var currentArtifact: RenderArtifact?
    @State private var isRendering = false

    // In a real app, these would be injected or come from a view model
    let gridRenderer = DataGridRenderer()
    let profilerRenderer = ProfilerRenderer()

    public init(selectionId: Binding<String?>, onCapture: ((String, String, URL) -> Void)? = nil) {
        self._selectionId = selectionId
        self.onCapture = onCapture
    }

    // Callbacks
    let onCapture: ((String, String, URL) -> Void)?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(workspaceTitle)
                    .font(.headline)
                Spacer()
                Picker("View Mode", selection: $selectedViewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                            .accessibilityLabel(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            if isRendering {
                ProgressView("Rendering...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                contentView
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .id(selectedViewMode)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isRendering)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedViewMode)
        .onChange(of: selectedViewMode) { _, newValue in
            Task {
                // Ensure data reload happens when view mode changes
                await loadMockData(for: newValue, selectionId: selectionId)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedViewMode {
        case .browser:
            BrowserLens(
                selection: $selectionId,
                onCapture: onCapture ?? { _, _, _ in }
            )
        case .diagram:
            DiagramLens(selection: $selectionId)
        case .plot:
            PlotLens(selection: $selectionId)
        case .grid, .profile, .visualize, .diff, .lineage:
            if let artifact = currentArtifact {
                switch selectedViewMode {
                case .grid:
                    DataGridView(artifact: artifact)
                case .profile:
                    ProfilerView(artifact: artifact)
                case .visualize:
                    Text("Visualize Placeholder")
                case .diff:
                    TransformPreviewView(changeArtifact: ChangeArtifact(
                        transformId: "demo",
                        recordsAffected: 42,
                        columnsChanged: ["amount"],
                        diffSummary: "Changed type of 'amount' from String to Double"
                    ))
                case .lineage:
                    Text("Lineage Placeholder")
                default:
                    EmptyView()
                }
            } else {
                VStack {
                    Text("No Data Loaded")
                    Button("Load Mock Data") {
                        Task {
                            await loadMockData(for: selectedViewMode, selectionId: selectionId)
                        }
                    }
                    .accessibilityHint("Loads sample data to demonstrate the workspace")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var workspaceTitle: String {
        switch selectedViewMode {
        case .browser: return "Web Ingestion"
        default: return "Data Workspace"
        }
    }

    private func loadMockData(for mode: ViewMode, selectionId: String? = nil) async {
        isRendering = true
        // Simulate network/processing delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        do {
            // Mocking input data
                let storagePointer = selectionId ?? "mock-pointer"
                let datasetId = selectionId ?? "mock-dataset"
                let viewSpec = ViewSpec(
                    query: "SELECT * FROM table",
                    parameters: [:],
                    filters: [],
                    sort: [],
                    sourceSnapshotId: UUID().uuidString
                )

                let artifact: RenderArtifact

                switch selectedViewMode {
                case .grid:
                    let schema = TableSchema(columns: [
                        ColumnSchema(name: "ID", type: .integer, isNullable: false),
                        ColumnSchema(name: "Name", type: .string, isNullable: true)
                    ])
                    let input = TabularIR(schema: schema, rowCount: 100, storagePointer: storagePointer)
                    artifact = try await gridRenderer.render(input: input, viewSpec: viewSpec)

                case .profile:
                     let input = ProfileArtifact(
                        datasetId: datasetId,
                        columnProfiles: [
                            "ID": ColumnProfile(inferredType: .integer, nullCount: 0, distinctCount: 100, topValues: [:]),
                            "Name": ColumnProfile(inferredType: .string, nullCount: 5, distinctCount: 90, topValues: [:])
                        ],
                        totalRows: 100,
                        parsingFailures: 0
                    )
                    artifact = try await profilerRenderer.render(input: input, viewSpec: viewSpec)

                default:
                    // Fallback for unimplemented modes
                    artifact = RenderArtifact(
                        rendererId: "unknown",
                        viewSpecId: UUID(),
                        data: Data()
                    )
                }

                await MainActor.run {
                    self.currentArtifact = artifact
                    self.isRendering = false
                }
            } catch {
                print("Rendering failed: \(error)")
                await MainActor.run {
                    self.isRendering = false
                }
            }
    }
}

public enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case diagram = "Diagram"
    case plot = "Plot"
    case profile = "Profile"
    case browser = "Browser"
    case visualize = "Visualize"
    case diff = "Diff"
    case lineage = "Lineage"

    var icon: String {
        switch self {
        case .grid: return "tablecells"
        case .diagram: return "network"
        case .plot: return "chart.xyaxis.line"
        case .profile: return "doc.text.magnifyingglass"
        case .browser: return "globe"
        case .visualize: return "eye"
        case .diff: return "arrow.left.and.right.square"
        case .lineage: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}
