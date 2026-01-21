import Foundation

// MARK: - PlanComponent
public struct PlanComponent: Renderable {
    public struct Task: Sendable, Identifiable {
        public let id: UUID
        public let title: String
        public var status: Status

        public enum Status: Sendable {
            case pending, inProgress, completed, failed
        }
    }

    public var tasks: [Task]

    public init(tasks: [Task]) {
        self.tasks = tasks
    }

    public func render(in frame: Rect, to buffer: TerminalBuffer) {
        let box = Box(borderColor: .gray, title: "AGENTIC PLAN", padding: 1) {
            VStack(spacing: 0) {
                for task in tasks {
                    HStack(spacing: 1) {
                        Text(statusIcon(for: task.status),
                             foreground: statusColor(for: task.status))
                        Text(task.title,
                             foreground: task.status == .completed ? .gray : .white,
                             attributes: task.status == .completed ? [.strikethrough] : [])
                    }
                }
            }
        }
        box.render(in: frame, to: buffer)
    }

    private func statusIcon(for status: Task.Status) -> String {
        switch status {
        case .pending: return "○"
        case .inProgress: return "▶"
        case .completed: return "✔"
        case .failed: return "✘"
        }
    }

    private func statusColor(for status: Task.Status) -> Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .brightCyan
        case .completed: return .brightGreen
        case .failed: return .brightRed
        }
    }
}
