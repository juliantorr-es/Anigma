import SwiftUI
import Combine
import ContractsCore
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum OperationProgressAnnouncement {
    @MainActor static var handler: (String) -> Void = defaultHandler

    private static let defaultHandler: (String) -> Void = { text in
        #if canImport(AppKit)
        if let app = NSApp {
            NSAccessibility.post(
                element: app,
                notification: .announcementRequested,
                userInfo: [.announcement: text]
            )
        }
        #elseif canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif
    }

    @MainActor static func post(_ text: String) {
        handler(text)
    }
}

@MainActor
final class OperationProgressViewModel<Payload: Codable & Sendable>: ObservableObject {
    @Published var latest: OperationResult<Payload>?
    @Published var progressValue: Double = 0
    @Published var statusText: String = "Preparing…"

    private var cancellables: Set<AnyCancellable> = []
    private let label: String
    private var lastAnnouncedBucket: Int = -1
    private var lastState: OperationResult<Payload>.State?

    init<P: Publisher>(publisher: P, label: String = "Operation") where P.Output == OperationResult<Payload>, P.Failure == Never {
        self.label = label

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.latest = result
                if let progress = result.progress {
                    self?.progressValue = progress.percent
                    if let message = progress.message, !message.isEmpty {
                        self?.statusText = message
                    }

                    self?.announceProgressIfNeeded(
                        percent: Int(progress.percent),
                        message: progress.message
                    )
                }

                switch result.state {
                case .success:
                    self?.progressValue = max(self?.progressValue ?? 0, 100)
                    self?.statusText = "Completed"
                    self?.announceStateChange(text: "Completed")
                case .failure:
                    self?.statusText = result.failure?.message ?? "Failed"
                    self?.announceStateChange(text: self?.statusText ?? "Failed")
                case .cancelled:
                    self?.statusText = "Cancelled"
                    self?.announceStateChange(text: "Cancelled")
                default:
                    break
                }

                self?.lastState = result.state
            }
            .store(in: &cancellables)
    }

    private func announceProgressIfNeeded(percent: Int, message: String?) {
        let bucket = percent / 10
        guard bucket != lastAnnouncedBucket else { return }
        lastAnnouncedBucket = bucket
        let text = message.map { "\(label) \(percent)%: \($0)" } ?? "\(label) \(percent)%"
        OperationProgressAnnouncement.post(text)
    }

    private func announceStateChange(text: String) {
        guard lastState != .success && lastState != .failure && lastState != .cancelled else { return }
        OperationProgressAnnouncement.post("\(label) \(text)")
    }
}

struct OperationProgressView<Payload: Codable & Sendable>: View {
    @ObservedObject var viewModel: OperationProgressViewModel<Payload>
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text(title)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .accessibilityHidden(true)

            ProgressView(value: viewModel.progressValue, total: 100) {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .accessibilityLabel("\(title) progress")
            .accessibilityValue("\(Int(viewModel.progressValue)) percent")
            .accessibilityHint("Progress updates announce on state changes.")

            Text(viewModel.statusText)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .accessibilityLabel("Status \(viewModel.statusText)")
        }
    }
}
