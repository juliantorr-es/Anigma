import Foundation

/// Model management TUI view
public actor ModelManagerView {
    private let engine: TUIEngine

    public struct ModelInfo: Sendable {
        public let name: String
        public let size: String
        public let status: ModelStatus
        public let progress: Double?

        public init(name: String, size: String, status: ModelStatus, progress: Double? = nil) {
            self.name = name
            self.size = size
            self.status = status
            self.progress = progress
        }
    }

    public enum ModelStatus: Sendable {
        case available
        case downloading
        case installed
        case error(String)
    }

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func render(models: [ModelInfo], selectedIndex: Int = 0) async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        // Title
        let title = engine.styled("📦 Model Management", color: .magenta, style: .bold)
        await engine.renderText(row: 2, col: (size.cols - 20) / 2, text: title)

        // Models list box
        await engine.drawBox(
            row: 4,
            col: 3,
            width: size.cols - 6,
            height: size.rows - 8,
            title: "Available Models"
        )

        // Render models
        var row = 6
        for (index, model) in models.enumerated() {
            let isSelected = index == selectedIndex
            let prefix = isSelected ? "→ " : "  "

            let statusIcon: String
            let statusColor: TUIEngine.Color

            switch model.status {
            case .available:
                statusIcon = "○"
                statusColor = .brightBlack
            case .downloading:
                statusIcon = "⟳"
                statusColor = .yellow
            case .installed:
                statusIcon = "●"
                statusColor = .green
            case .error:
                statusIcon = "✗"
                statusColor = .red
            }

            let styledStatus = engine.styled(statusIcon, color: statusColor)
            let modelName = isSelected ? engine.styled(model.name, style: .bold) : model.name

            await engine.renderText(
                row: row,
                col: 5,
                text: "\(prefix)\(styledStatus) \(modelName) (\(model.size))"
            )
            row += 1

            // Show progress bar if downloading
            if case .downloading = model.status, let progress = model.progress {
                await engine.renderProgressBar(
                    row: row,
                    col: 7,
                    width: size.cols - 14,
                    progress: progress
                )
                row += 1
            }

            // Show error message if error
            if case .error(let message) = model.status {
                await engine.renderError(row: row, col: 7, message: message, maxWidth: size.cols - 14)
                row += 1
            }

            row += 1
            if row >= size.rows - 4 { break }
        }

        // Footer with controls
        let controls = "↑/↓: Navigate  •  Enter: Install/Remove  •  R: Refresh  •  Q: Quit"
        let footer = engine.styled(controls, color: .black, bg: .white)
        await engine.renderText(row: size.rows, col: 1, text: footer, maxWidth: size.cols)
    }
}
