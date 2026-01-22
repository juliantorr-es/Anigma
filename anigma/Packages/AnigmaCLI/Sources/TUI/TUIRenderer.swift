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
    
    // Elevated State
    private var isChatExpanded: Bool = false
    private var dataSpans: [String] = []
    private var evidenceLog: [String] = []

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
        self.tuiRenderer = TerminalRenderer(size: Size(width: 120, height: 40))
    }

    // MARK: - Elevated API
    public func toggleChatExpansion() {
        self.isChatExpanded.toggle()
        render()
    }
    
    public func setDataSpans(_ spans: [String]) {
        self.dataSpans = spans
        render()
    }
    
    public func appendEvidence(_ log: String) {
        self.evidenceLog.append(log)
        if evidenceLog.count > 12 {
            evidenceLog.removeFirst()
        }
        render()
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
        let line = "[\(timestamp)] \(event.message)"
        appendLog(line)
        
        // Also add to evidence if it's a governance or execution event
        if event.kind == .governance || event.kind == .execution {
            appendEvidence(event.message)
        }
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
        let expanded = isChatExpanded
        let spans = dataSpans
        let evidence = evidenceLog

        let root = Box(borderColor: .blue, title: "ANIGMA COMMAND CENTER", padding: 1) {
            VStack(spacing: 1) {
                // Status Bar
                HStack(spacing: 2) {
                    Text("STATUS:", foreground: .gray)
                    Text(currentStatus.uppercased(),
                         foreground: currentStatus == "idle" ? .gray : .brightGreen,
                         attributes: [.bold])

                    Text("DAEMON:", foreground: .gray)
                    Text("ACTIVE", foreground: .brightGreen)

                    Text("MODE:", foreground: .gray)
                    Text(currentMode.rawValue.uppercased(), foreground: .brightCyan)

                    Spacer()

                    Text("MODEL:", foreground: .gray)
                    Text(currentModelName, foreground: .brightMagenta)

                    Spinner(width: 8, frame: currentFrame, color: .magenta)
                }

                // Main Layout
                HStack(spacing: 1) {
                    // Chat Area
                    Box(borderColor: expanded ? .brightCyan : .gray, title: "Interactive Chat") {
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

                    // Data Inspector (Right Panel)
                    if !expanded {
                        Box(borderColor: .gray, title: "Data Inspector") {
                            VStack(spacing: 1) {
                                Text("CONTEXT SPANS", foreground: .yellow, attributes: [.bold])
                                if spans.isEmpty {
                                    Text("No active context", foreground: .dim)
                                } else {
                                    for span in spans.prefix(8) {
                                        Text("• \(span.prefix(25))...", foreground: .white)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("EVIDENCE CHAIN", foreground: .brightGreen, attributes: [.bold])
                                if evidence.isEmpty {
                                    Text("Awaiting execution...", foreground: .dim)
                                } else {
                                    for entry in evidence {
                                        Text("> \(entry.prefix(30))", foreground: .gray)
                                    }
                                }
                            }
                        }
                    }
                }

                // Toolbar / Footer
                HStack(spacing: 2) {
                    Text("[TAB]", foreground: .brightYellow)
                    Text("Toggle View", foreground: .gray)
                    
                    Text("[CTRL+P]", foreground: .brightCyan)
                    Text("Command Palette", foreground: .gray)
                    
                    Text("[CTRL+R]", foreground: .brightGreen)
                    Text("Restart Daemon", foreground: .gray)
                    
                    Spacer()
                    
                    if contextChunks > 0 {
                        Text("CONTEXT:", foreground: .gray)
                        Text("\(contextChunks) chunks", foreground: .brightBlue)
                    }
                    
                    Text("DRY-RUN:", foreground: .gray)
                    Text(currentDryRun ? "ON" : "OFF", foreground: currentDryRun ? .brightYellow : .gray)
                }
            }
        }

        Task {
            await tuiRenderer.render(root)
        }
    }
}
