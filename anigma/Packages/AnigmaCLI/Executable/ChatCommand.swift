//
//  ChatCommand.swift
//  AnigmaCLIExecutable
//
//  Interactive chat/coding mode with embedded MCP tools and local ML inference.
//

import Foundation
import ArgumentParser
import AnigmaCLICore
import AnigmaCLIDatabase
import AnigmaCore
import AnigmaCLIProviders
import AnigmaCLIML
import AnigmaCLIRAG
import AnigmaCLITUI
import HarmoniaModule
import AnigmaPrimitives

#if canImport(MLX)
import MLX
#endif

struct AnigmaChatCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "chat",
            abstract: "Start interactive chat/coding mode."
        )
    }

    @Option(name: .long, help: "Model to use (llama-3.1-8b, qwen-2.5-7b).")
    var model: String = "llama-3.1-8b-instruct-4bit"

    @Flag(name: .long, help: "Disable MCP tools.")
    var noTools: Bool = false

    @Flag(name: .long, help: "Dry-run mode (no file modifications).")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Enable streaming responses.")
    var stream: Bool = true

    @Option(name: .long, help: "Backend to use (mlx, llama, cloud).")
    var backend: String?

    mutating func run() async throws {
        // Initialize database
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()

        // Initialize ML backend coordinator
        let mlConfig = try await loadMLConfig()
        let mlCoordinator = MLBackendCoordinator(config: mlConfig)
        try await mlCoordinator.initialize()

        // Initialize Harmonia Tooling
        let toolRegistry = ToolRegistry.shared
        let loopBreaker = ToolCallLoopBreaker()
        let policyGate = PolicyGate()
        let evidenceRecorder = LoopMockEvidenceRecorder() // Use correct class name
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let toolRouter = ToolRouter(
            loopBreaker: loopBreaker,
            policyGate: policyGate,
            evidenceRecorder: evidenceRecorder,
            toolRegistry: toolRegistry,
            modernToolRegistry: ModernToolRegistry.shared
        )

        // Bootstrap tools
        let simpleBootstrap = SimpleToolBootstrap.Config(
            projectDirectory: repoRoot.path,
            enableCodeAnalysis: true,
            mode: .real
        )
        try await SimpleToolBootstrap.configure(registry: SimpleToolRegistry(), config: simpleBootstrap)

        // Initialize vector RAG pipeline with ML backend
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".anigma/anigma.db").path
        let ragPipeline = VectorRAGPipeline(
            dbPath: dbPath,
            chunkSize: 512,
            overlapSize: 128,
            embeddingProvider: mlCoordinator
        )
        try await ragPipeline.initialize()

        // Create session
        let sessionID = UUID().uuidString
        _ = try await db.execute("INSERT INTO runs (run_id, task_summary, task_details, mode, dry_run, status, created_at, spec_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", parameters: [.text(sessionID), .text("Chat session"), .text("Interactive chat mode"), .text("chat"), .int(dryRun ? 1 : 0), .text("running"), .double(Date().timeIntervalSince1970), .text("")])

                // TUI Setup

                let engine = TUIEngine()

                let container = TUIContainer(engine: engine)

                        let messageList = MessageListView()

                        let statusBar = StatusBarView()

                        let inputArea = InputAreaView()

                        let commandPalette = CommandPaletteView()
                        
                        let dataInspector = DataInspectorView()

                        await container.addComponent(messageList)
                        
                        await container.addComponent(dataInspector)

                        await container.addComponent(inputArea)

                        await container.addComponent(statusBar)

                        await container.addComponent(commandPalette)

                        // Setup initial commands

                        commandPalette.setCommands([

                            Command(id: "theme_default", title: "Theme: Default", description: "Switch to default theme") {

                                await TUIThemeManager.shared.setTheme(.defaultTheme)

                            },

                            Command(id: "theme_matrix", title: "Theme: Matrix", description: "Switch to matrix theme") {

                                await TUIThemeManager.shared.setTheme(.matrixTheme)

                            },

                            Command(id: "exit", title: "Exit", description: "Quit Anigma CLI") {

                                await TUIEventBus.shared.publish(.inputCommitted(text: "/exit"))

                            }

                        ])

                        // 5. Initialize Presenter (Remote)
                        // Connect to Sidecar
                        do {
                            let bridge = try await SidecarBridge.create(clientName: "anigma-cli-chat")
                            let presenter = ChatPresenter(sidecar: bridge, sessionID: sessionID)
                            await presenter.start()
                        } catch {
                            print("❌ Failed to connect to daemon: \(error)")
                            return
                        }
                        
                        // Handle Resize Signal (SIGWINCH)

                                let signalSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .main)

                                signalSource.setEventHandler {

                                    Task {

                                        await container.resize()

                                    }

                                }

                                signalSource.resume()

                                let inputHandler = InputHandler()

                        // Start 60 FPS render loop

                let renderTask = Task.detached(priority: .userInitiated) {

                    while !Task.isCancelled {

                        await container.render()

                        try? await Task.sleep(nanoseconds: 16_666_666)

                    }

                }

                // Enter Raw Mode

                try await engine.enableRawMode()

                // Initial Greeting

                messageList.addMessage(role: "system", content: "Welcome to Anigma CLI! (Modular TUI Mode)")

                // Main Loop (Event Stream)

                for await key in inputHandler.events {

                    if case .ctrlC = key {

                        renderTask.cancel()

                        await engine.disableRawMode()

                        await engine.clearScreen()

                        print("👋 Goodbye!")

                        return

                    }

                    _ = await container.dispatchKey(key)
                }    }
}

enum ChatError: Error {
    case gitCommandFailed
}

