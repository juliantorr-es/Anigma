import Foundation

/// Diagnostics and system status TUI view
public actor DiagnosticsView {
    private let engine: TUIEngine

    public struct SystemStatus: Sendable {
        public let cpuUsage: Double
        public let memoryUsage: Double
        public let diskUsage: Double
        public let gpuAvailable: Bool
        public let mlxAvailable: Bool
        public let llamaCppAvailable: Bool

        public init(cpuUsage: Double, memoryUsage: Double, diskUsage: Double, gpuAvailable: Bool, mlxAvailable: Bool, llamaCppAvailable: Bool) {
            self.cpuUsage = cpuUsage
            self.memoryUsage = memoryUsage
            self.diskUsage = diskUsage
            self.gpuAvailable = gpuAvailable
            self.mlxAvailable = mlxAvailable
            self.llamaCppAvailable = llamaCppAvailable
        }
    }

    public struct ServiceStatus: Sendable {
        public let name: String
        public let status: Status
        public let uptime: TimeInterval?
        public let message: String?

        public enum Status: Sendable {
            case running, stopped, error
        }

        public init(name: String, status: Status, uptime: TimeInterval? = nil, message: String? = nil) {
            self.name = name
            self.status = status
            self.uptime = uptime
            self.message = message
        }
    }

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func render(system: SystemStatus, services: [ServiceStatus], logs: [String] = []) async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        // Title
        let title = engine.styled("⚙️  System Diagnostics", color: .yellow, style: .bold)
        await engine.renderText(row: 2, col: (size.cols - 25) / 2, text: title)

        // System metrics box
        await engine.drawBox(row: 4, col: 3, width: (size.cols / 2) - 4, height: 10, title: "System Metrics")

        var row = 5
        await engine.renderText(row: row, col: 5, text: "CPU Usage:")
        await engine.renderProgressBar(row: row, col: 20, width: 20, progress: system.cpuUsage)
        row += 1

        await engine.renderText(row: row, col: 5, text: "Memory:")
        await engine.renderProgressBar(row: row, col: 20, width: 20, progress: system.memoryUsage)
        row += 1

        await engine.renderText(row: row, col: 5, text: "Disk:")
        await engine.renderProgressBar(row: row, col: 20, width: 20, progress: system.diskUsage)
        row += 2

        let gpuStatus = system.gpuAvailable ? engine.styled("✓", color: .green) : engine.styled("✗", color: .red)
        await engine.renderText(row: row, col: 5, text: "GPU: \(gpuStatus)")
        row += 1

        let mlxStatus = system.mlxAvailable ? engine.styled("✓", color: .green) : engine.styled("✗", color: .red)
        await engine.renderText(row: row, col: 5, text: "MLX: \(mlxStatus)")
        row += 1

        let llamaStatus = system.llamaCppAvailable ? engine.styled("✓", color: .green) : engine.styled("✗", color: .red)
        await engine.renderText(row: row, col: 5, text: "llama.cpp: \(llamaStatus)")

        // Services box
        let servicesWidth = (size.cols / 2) - 1
        await engine.drawBox(row: 4, col: (size.cols / 2) + 1, width: servicesWidth, height: 10, title: "Services")

        row = 5
        for service in services.prefix(6) {
            let statusIcon: String
            let statusColor: TUIEngine.Color

            switch service.status {
            case .running:
                statusIcon = "●"
                statusColor = .green
            case .stopped:
                statusIcon = "○"
                statusColor = .brightBlack
            case .error:
                statusIcon = "✗"
                statusColor = .red
            }

            let styledStatus = engine.styled(statusIcon, color: statusColor)
            let uptimeStr = service.uptime.map { formatUptime($0) } ?? ""

            await engine.renderText(
                row: row,
                col: (size.cols / 2) + 3,
                text: "\(styledStatus) \(service.name) \(uptimeStr)",
                maxWidth: servicesWidth - 4
            )
            row += 1
        }

        // Logs box
        let logsHeight = size.rows - 16
        await engine.drawBox(row: 15, col: 3, width: size.cols - 6, height: logsHeight, title: "Recent Logs")

        row = 16
        for log in logs.suffix(logsHeight - 2) {
            let logColor: TUIEngine.Color = log.contains("ERROR") ? .red : log.contains("WARN") ? .yellow : .white
            let styledLog = engine.styled(log, color: logColor)
            await engine.renderText(row: row, col: 5, text: styledLog, maxWidth: size.cols - 10)
            row += 1
        }

        // Footer
        let controls = "R: Refresh  •  L: Clear Logs  •  Q: Quit"
        let footer = engine.styled(controls, color: .black, bg: .white)
        await engine.renderText(row: size.rows, col: 1, text: footer, maxWidth: size.cols)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return String(format: "(%dh %dm)", hours, minutes)
    }
}
