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
            }
            .navigationTitle("Action Catalog")
            .searchable(text: $searchText, prompt: "Search actions...")
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: action.family))
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.name)
                    .font(.headline)
                Text(action.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
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

                parametersSection

                Divider()

                policySection

                Divider()

                TestEvaluationSection(action: action)
            }
            .padding()
        }
        .navigationTitle(action.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(action.family.uppercased(), systemImage: "tag.fill")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(action.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(action.description)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)

            if action.parameters.isEmpty {
                Text("No parameters required.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(action.parameters.keys).sorted(), id: \.self) { key in
                    guard let schema = action.parameters[key] else {
                        fatalError("Failed to unwrap schema")
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(key)
                                .font(.monospaced(.body)())
                                .fontWeight(.semibold)
                            Text(String(describing: schema.type).capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if schema.required {
                            Text("Required")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(key), type \(String(describing: schema.type).capitalized)\(schema.required ? ", required" : "")")
                }
            }
        }
    }

    private var policySection: some View {
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
                }
            }
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
