//
//  TUIRenderer.swift
//  AnigmaCLI
//

import Foundation
import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaTUI

public actor TUIRenderer {
    // MARK: - State
    private var logs: [String] = []
    private var maxLogs: Int
    private var mode: ExecutionMode
    private var dryRun: Bool
    private var status: String
    private var currentModel: String
    private var contextChunks: Int = 0
    private var toolsEnabled: Bool

    private let tuiRenderer: TerminalRenderer
    private var frameCount: Int = 0

    // MARK: - Initialization
    public init(
        mode: ExecutionMode = .plan,
        dryRun: Bool = true,
        model: String = "llama-3.1-8b-instruct-4bit",
        toolsEnabled: Bool = true,
        maxLogs: Int = 20
    ) {
        self.mode = mode
        self.dryRun = dryRun
        self.currentModel = model
        self.toolsEnabled = toolsEnabled
        self.status = "idle"
        self.maxLogs = maxLogs
        self.tuiRenderer = TerminalRenderer(size: Size(width: 100, height: 30))
    }

    // MARK: - State Updates
    public func setMode(_ mode: ExecutionMode) {
        self.mode = mode
        render()
    }

    public func setDryRun(_ dryRun: Bool) {
        self.dryRun = dryRun
        render()
    }

    public func setStatus(_ status: String) {
        self.status = status
        render()
    }

    public func setModel(_ model: String) {
        self.currentModel = model
        render()
    }

    public func setToolsEnabled(_ enabled: Bool) {
        self.toolsEnabled = enabled
        render()
    }

    public func setContextChunks(_ count: Int) {
        self.contextChunks = count
        render()
    }

    // MARK: - Log Management
    public func appendEvent(_ event: CLIEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: event.timestamp)
        let line = "[\(timestamp)] [\(event.kind.rawValue.uppercased())] \(event.message)"
        appendLog(line)
    }

    public func appendLog(_ line: String) {
        logs.append(line)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        render()
    }

    public func clearLogs() {
        logs.removeAll()
        render()
    }

    // MARK: - Rendering
    public func render() {
        frameCount += 1
        let currentFrame = frameCount
        let currentStatus = status
        let currentMode = mode
        let currentDryRun = dryRun
        let currentTools = toolsEnabled
        let currentModelName = currentModel
        let currentLogs = logs

        let root = Box(borderColor: .blue, title: "ANIGMA CLI", padding: 1) {
            VStack(spacing: 1) {
                // Status Bar
                HStack(spacing: 2) {
                    Text("STATUS:", foreground: .gray)
                    Text(currentStatus.uppercased(),
                         foreground: currentStatus == "idle" ? .gray : .brightGreen,
                         attributes: [.bold])

                    Text("MODE:", foreground: .gray)
                    Text(currentMode.rawValue.uppercased(), foreground: .brightCyan)

                    Spacer()

                    Text("MODEL:", foreground: .gray)
                    Text(currentModelName, foreground: .brightMagenta)

                    Spinner(width: 10, frame: currentFrame, color: .magenta)
                }

                // Config line
                HStack(spacing: 2) {
                    Text("DRY-RUN:", foreground: .gray)
                    Text(currentDryRun ? "ON" : "OFF", foreground: currentDryRun ? .brightYellow : .gray)

                    Text("TOOLS:", foreground: .gray)
                    Text(currentTools ? "ON" : "OFF", foreground: currentTools ? .brightGreen : .brightRed)

                    if contextChunks > 0 {
                        Text("CONTEXT:", foreground: .gray)
                        Text("\(contextChunks) chunks", foreground: .brightBlue)
                    }
                }

                // Main Log Area
                Box(borderColor: .gray, title: "Live Logs") {
                    VStack {
                        if currentLogs.isEmpty {
                            Text("Waiting for events...", foreground: .gray, attributes: [.italic])
                        } else {
                            for log in currentLogs {
                                Text(log)
                            }
                        }
                    }
                }

                Spacer()

                // Commands Help
                HStack {
                    Text("COMMANDS: ", foreground: .gray)
                    Text(":plan :run :execute :quit /model /index /search", foreground: .white)
                }

                // Input Line
                HStack {
                    Text("> ", foreground: .brightCyan, attributes: [.bold])
                    Text("Enter command or prompt...", foreground: .gray)
                    Spacer()
                }
            }
        }

        Task {
            await tuiRenderer.render(root)
        }
    }
}
