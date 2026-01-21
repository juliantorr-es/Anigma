import SwiftUI
import ExportCore

public struct UniversalExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var request: ExportRequest
    @State private var engine: ExportEngine
    @State private var events: [ExportEvent] = []
    @State private var isRunning = false

    public init(engine: ExportEngine) {
        self.engine = engine
        self._request = State(initialValue: ExportRequest(
            inputs: [],
            profileId: "default",
            target: .folder(url: URL(fileURLWithPath: "/tmp"))
        ))
    }

    public var body: some View {
        VStack {
            HStack {
                Text("Export").font(.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.bottom)

            // Inputs
            GroupBox("Inputs") {
                List(request.inputs, id: \.self) { input in
                    Text(String(describing: input))
                }
                .accessibilityLabel("Export Inputs")
            }

            // Profile
            GroupBox("Profile") {
                TextField("Profile ID", text: $request.profileId)
                    .accessibilityLabel("Profile Identifier")
            }

            // Target
            GroupBox("Target") {
                Text(String(describing: request.target))
                    .accessibilityLabel("Target Destination")
                    .accessibilityValue(String(describing: request.target))
            }

            // Run Panel
            if isRunning {
                ProgressView("Exporting...")
                    .accessibilityLabel("Export in progress")
                List(events, id: \.self) { event in
                    Text(String(describing: event))
                }
                .accessibilityLabel("Export Events Log")
            } else {
                Button("Start Export") {
                    startExport()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func startExport() {
        isRunning = true
        events = []

        Task {
            do {
                let plan = try await engine.compilePlan(request: request)
                for await event in await engine.execute(plan: plan) {
                    events.append(event)
                }
                isRunning = false
            } catch {
                events.append(.failed(message: error.localizedDescription, receiptRef: nil))
                isRunning = false
            }
        }
    }
}

// Helper for List id
extension ExportEvent: Hashable {
    public static func == (lhs: ExportEvent, rhs: ExportEvent) -> Bool {
        switch (lhs, rhs) {
        case (.started(let l), .started(let r)): return l == r
        case (.phase(let l), .phase(let r)): return l == r
        case (.progress(let lc, let lt), .progress(let rc, let rt)): return lc == rc && lt == rt
        case (.output(let lu, let lr), .output(let ru, let rr)): return lu == ru && lr == rr
        case (.finished(let ls, let lr), .finished(let rs, let rr)): return ls == rs && lr == rr
        case (.failed(let lm, let lr), .failed(let rm, let rr)): return lm == rm && lr == rr
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .started(let id): hasher.combine("started"); hasher.combine(id)
        case .phase(let name): hasher.combine("phase"); hasher.combine(name)
        case .progress(let c, let t): hasher.combine("progress"); hasher.combine(c); hasher.combine(t)
        case .output(let u, let r): hasher.combine("output"); hasher.combine(u); hasher.combine(r)
        case .finished(let s, let r): hasher.combine("finished"); hasher.combine(s); hasher.combine(r)
        case .failed(let m, let r): hasher.combine("failed"); hasher.combine(m); hasher.combine(r)
        }
    }
}
