import Foundation

/// Interactive chat interface for the CLI
actor ChatInterface {
    private let config: CLIConfiguration
    private let database: CLIDatabase
    private let agentOrchestrator: AgentOrchestrator
    private let ui: TUIManager
    private var sessionID: String
    private var conversationHistory: [Message] = []

    init(config: CLIConfiguration, database: CLIDatabase, ui: TUIManager) async throws {
        self.config = config
        self.database = database
        self.ui = ui
        self.agentOrchestrator = try await AgentOrchestrator(config: config, database: database)
        self.sessionID = UUID().uuidString

        try await initializeSession()
    }

    private func initializeSession() async throws {
        // Create new session in database
        let statement = """
            INSERT INTO sessions (id, started_at, workspace_path)
            VALUES (?, ?, ?)
            """

        let workspacePath = try await config.getWorkspacePath()
        try await database.execute(
            statement,
            params: [
                .text(sessionID),
                .integer(Int64(Date().timeIntervalSince1970)),
                .text(workspacePath)
            ]
        )
    }

    func start() async throws {
        await ui.showSection("Chat Session")
        await ui.showInfo("Type your request, '/help' for commands, or '/exit' to quit")
        await ui.showInfo("")

        while true {
            print("\n> ", terminator: "")
            fflush(stdout)

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
                continue
            }

            if input.isEmpty {
                continue
            }

            // Handle commands
            if input.hasPrefix("/") {
                let shouldContinue = try await handleCommand(input)
                if !shouldContinue {
                    break
                }
                continue
            }

            // Process user message
            try await processMessage(input)
        }

        try await endSession()
    }

    private func handleCommand(_ command: String) async throws -> Bool {
        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = String(parts[0]).lowercased()
        let args = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "/exit", "/quit", "/q":
            await ui.showInfo("Goodbye!")
            return false

        case "/help", "/h":
            await showHelp()

        case "/clear", "/c":
            await ui.clearScreen()
            conversationHistory.removeAll()
            await ui.showInfo("Conversation cleared")

        case "/history":
            await showHistory()

        case "/tools":
            await listTools()

        case "/models":
            await listModels()

        case "/provider":
            if args.isEmpty {
                await showCurrentProvider()
            } else {
                try await switchProvider(args)
            }

        case "/workspace":
            if args.isEmpty {
                await showWorkspace()
            } else {
                try await changeWorkspace(args)
            }

        default:
            await ui.showError("Unknown command: \(cmd)")
            await ui.showInfo("Type '/help' for available commands")
        }

        return true
    }

    private func processMessage(_ userMessage: String) async throws {
        let message = Message(
            role: .user,
            content: userMessage,
            timestamp: Date()
        )

        conversationHistory.append(message)
        try await saveMessage(message)

        await ui.showInfo("")
        await ui.showSpinner("Thinking...")

        do {
            let response = try await agentOrchestrator.processRequest(
                userMessage,
                history: conversationHistory,
                sessionID: sessionID
            )

            await ui.hideSpinner()

            let assistantMessage = Message(
                role: .assistant,
                content: response,
                timestamp: Date()
            )

            conversationHistory.append(assistantMessage)
            try await saveMessage(assistantMessage)

            print("\n\(response)\n")

        } catch {
            await ui.hideSpinner()
            await ui.showError("Error: \(error.localizedDescription)")
        }
    }

    private func saveMessage(_ message: Message) async throws {
        let statement = """
            INSERT INTO messages (id, session_id, role, content, timestamp)
            VALUES (?, ?, ?, ?, ?)
            """

        try await database.execute(
            statement,
            params: [
                .text(UUID().uuidString),
                .text(sessionID),
                .text(message.role.rawValue),
                .text(message.content),
                .integer(Int64(message.timestamp.timeIntervalSince1970))
            ]
        )
    }

    private func endSession() async throws {
        let statement = """
            UPDATE sessions SET ended_at = ? WHERE id = ?
            """

        try await database.execute(
            statement,
            params: [
                .integer(Int64(Date().timeIntervalSince1970)),
                .text(sessionID)
            ]
        )
    }

    // Command implementations

    private func showHelp() async {
        await ui.showSection("Available Commands")
        await ui.showInfo("/help, /h         - Show this help message")
        await ui.showInfo("/exit, /quit, /q  - Exit the chat session")
        await ui.showInfo("/clear, /c        - Clear conversation history")
        await ui.showInfo("/history          - Show conversation history")
        await ui.showInfo("/tools            - List available tools")
        await ui.showInfo("/models           - List installed models")
        await ui.showInfo("/provider [name]  - Show or switch inference provider")
        await ui.showInfo("/workspace [path] - Show or change workspace directory")
    }

    private func showHistory() async {
        await ui.showSection("Conversation History")

        for (index, message) in conversationHistory.enumerated() {
            let roleIcon = message.role == .user ? "👤" : "🤖"
            await ui.showInfo("\(index + 1). \(roleIcon) \(message.role.rawValue):")

            let preview = message.content.prefix(100)
            if message.content.count > 100 {
                await ui.showInfo("   \(preview)...")
            } else {
                await ui.showInfo("   \(preview)")
            }
        }
    }

    private func listTools() async {
        await ui.showSection("Available Tools")

        let tools = await agentOrchestrator.availableTools()
        for tool in tools {
            await ui.showInfo("• \(tool)")
        }
    }

    private func listModels() async {
        await ui.showSection("Installed Models")

        do {
            let installer = ModelInstaller(config: config, database: database)
            let models = try await installer.listInstalled()

            for model in models {
                await ui.showInfo("• \(model.name) (\(model.type.rawValue), \(model.sizeGB)GB)")
            }

            if models.isEmpty {
                await ui.showInfo("No models installed")
            }
        } catch {
            await ui.showError("Failed to list models: \(error.localizedDescription)")
        }
    }

    private func showCurrentProvider() async {
        do {
            let provider = try await config.getCurrentProvider()
            await ui.showInfo("Current provider: \(provider)")
        } catch {
            await ui.showError("No provider configured")
        }
    }

    private func switchProvider(_ name: String) async throws {
        try await config.setCurrentProvider(name)
        await ui.showSuccess("Switched to provider: \(name)")
    }

    private func showWorkspace() async {
        do {
            let workspace = try await config.getWorkspacePath()
            await ui.showInfo("Current workspace: \(workspace)")
        } catch {
            await ui.showError("No workspace configured")
        }
    }

    private func changeWorkspace(_ path: String) async throws {
        try await config.setWorkspacePath(path)
        await ui.showSuccess("Changed workspace to: \(path)")
    }
}

struct Message: Codable {
    let role: MessageRole
    let content: String
    let timestamp: Date
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}
