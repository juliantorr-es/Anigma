import ContractsCore
import SwiftUI

struct ActionCatalogView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""

    var filteredActions: [ActionDefinition] {
        if searchText.isEmpty {
            return store.actionCatalog
        } else {
            return store.actionCatalog.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.description.localizedCaseInsensitiveContains(searchText)
                    || $0.family.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredActions, id: \.name) { action in
                NavigationLink {
                    ActionDetailView(action: action)
                } label: {
                    ActionRow(action: action)
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .navigationTitle("Action Catalog")
            .searchable(text: $searchText, prompt: "Search actions...")
            .background(Bauhaus.Color.background)
            .overlay {
                if filteredActions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

struct ActionRow: View {
    let action: ActionDefinition

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon(for: action.family))
                .font(.system(size: 14))
                .foregroundStyle(Bauhaus.Color.accent)
                .frame(width: 32, height: 32)
                .background(Bauhaus.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Bauhaus.Color.border, lineWidth: 0.5))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(action.name)
                    .font(Bauhaus.Font.bodyBold)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                Text(action.description)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius).stroke(Bauhaus.Color.border, lineWidth: 1))
    }

    private func icon(for family: String) -> String {
        switch family {
        case "filesystem": return "doc.fill"
        case "network": return "globe"
        case "ui": return "macwindow"
        default: return "gearshape.fill"
        }
    }
}

struct ActionDetailView: View {
    let action: ActionDefinition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Divider()

                PolicySection(action: action)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Execution")
                        .font(.headline)

                    Text("Configure and run this tool against the Anigma runtime.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink(destination: ToolRunnerView(action: action)) {
                        Label("Initialize Tool Runner", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }

                Divider()

                TestEvaluationSection(action: action)
            }
            .padding()
        }
        .navigationTitle(action.displayName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(action.family.uppercased(), systemImage: icon(for: action.family))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(action.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(action.description)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func icon(for family: String) -> String {
        switch family {
        case "core": return "cpu"
        case "filesystem": return "doc.fill"
        case "network": return "globe"
        case "ui": return "macwindow"
        default: return "gearshape.fill"
        }
    }
}

struct PolicySection: View {
    let action: ActionDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Governing Policy")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Resource Mapping")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(
                    "This action is governed by the scope of the target resource URI it generates. The authority evaluates your trust level against the resource scope."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct TestEvaluationSection: View {
    let action: ActionDefinition
    @Environment(AppStore.self) private var store
    @State private var evaluationResult: IntentEvaluation?  // Renamed from 'result'
    @State private var isEvaluating = false

    /// Check if store is properly initialized for evaluation
    private var isStoreReady: Bool {
        store.surfaceId != nil && store.actorId != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Policy Test")
                .font(.headline)

            Text(
                "Evaluate this action against the current authority to see if your trust tier permits execution."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !isStoreReady {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Store not initialized. Connect to authority first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            Button(action: testAction) {
                if isEvaluating {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Evaluating policy...")
                } else {
                    Text(isStoreReady ? "Run Evaluation Check" : "Run Test Evaluation")
                        .frame(maxWidth: .infinity)
                }
            }
            .primaryButtonStyle()
            .disabled(isEvaluating)

            if evaluationResult != nil {
                HStack {
                    Image(systemName: isAllowed ? "checkmark.seal.fill" : "xmark.shield.fill")
                    VStack(alignment: .leading) {
                        Text(isAllowed ? "Allowed" : "Denied")
                            .fontWeight(.bold)
                        Text(reason)
                            .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isAllowed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .foregroundStyle(isAllowed ? Color.green : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var isAllowed: Bool {
        if case .allowed = evaluationResult { return true }  // Used 'evaluationResult' here
        return false
    }

    private var reason: String {
        switch evaluationResult {  // Used 'evaluationResult' here
        case .allowed: return "Default policy allows this action."
        case .denied(let reason): return reason
        case .needsConfirmation(let prompt): return "Confirmation required: \(prompt)"
        case nil: return ""
        }
    }

    func testAction() {
        isEvaluating = true
        Task {
            // Use real IDs if available, otherwise use deterministic test IDs for sandbox evaluation
            let surfaceId = store.surfaceId ?? SurfaceId(rawValue: "test-surface-\(action.name)")
            let actorId = store.actorId ?? ActorId(rawValue: "test-actor")

            // Generate a deterministic test token based on action being tested
            let testToken = "test-eval-\(action.name.hashValue)"
            let testSnapshot = "snapshot-\(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400))"

            let intent = ActionIntent(
                header: ActionIntent.Header(
                    surfaceId: surfaceId,
                    actorId: actorId,
                    capabilityToken: testToken,  // Test evaluation uses sandbox token
                    irSnapshotId: testSnapshot
                ),
                action: ActionRef(rawValue: action.name, family: action.family),
                parameters: [:]
            )
            evaluationResult = await store.evaluateAction(intent: intent)  // Used 'evaluationResult' here
            withAnimation {
                isEvaluating = false
            }
        }
    }
}
