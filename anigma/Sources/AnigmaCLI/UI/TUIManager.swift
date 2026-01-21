import Foundation

/// Terminal UI Manager for interactive CLI interface
actor TUIManager {
    private var currentSpinner: Task<Void, Never>?

    func showWelcome() {
        clearScreen()
        print("""
        ╔═══════════════════════════════════════════════════════════╗
        ║                                                           ║
        ║           🌟  Welcome to Anigma CLI  🌟                  ║
        ║                                                           ║
        ║     Your AI-powered development assistant                ║
        ║                                                           ║
        ╚═══════════════════════════════════════════════════════════╝

        """)
    }

    func showSection(_ title: String) {
        print("\n\n╔═══════════════════════════════════════════════════════════╗")
        print("║ \(title.padding(toLength: 57, withPad: " ", startingAt: 0)) ║")
        print("╚═══════════════════════════════════════════════════════════╝\n")
    }

    func showInfo(_ message: String) {
        print("  \(message)")
    }

    func showSuccess(_ message: String) {
        print("  ✓ \(message)")
    }

    func showError(_ message: String) {
        print("  ✗ \(message)")
    }

    func showWarning(_ message: String) {
        print("  ⚠️  \(message)")
    }

    func selectOption(prompt: String, options: [String]) async throws -> Int {
        print("\n\(prompt)")
        for (index, option) in options.enumerated() {
            print("  \(index + 1). \(option)")
        }

        while true {
            print("\nEnter selection (1-\(options.count)): ", terminator: "")
            fflush(stdout)

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  let selection = Int(input),
                  (1...options.count).contains(selection) else {
                print("Invalid selection. Please try again.")
                continue
            }

            return selection - 1
        }
    }

    func multiSelect(options: [String]) async throws -> [Int] {
        print("\nUse comma-separated numbers (e.g., 1,3,5) or 'all':")
        for (index, option) in options.enumerated() {
            print("  \(index + 1). \(option)")
        }

        while true {
            print("\nSelection: ", terminator: "")
            fflush(stdout)

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
                continue
            }

            if input.lowercased() == "all" {
                return Array(0..<options.count)
            }

            let components = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            var selected: [Int] = []
            var valid = true

            for component in components {
                if let num = Int(component), (1...options.count).contains(num) {
                    selected.append(num - 1)
                } else {
                    print("Invalid selection: \(component)")
                    valid = false
                    break
                }
            }

            if valid && !selected.isEmpty {
                return selected.sorted()
            }
        }
    }

    func prompt(_ message: String, default defaultValue: String? = nil) async throws -> String {
        if let defaultValue = defaultValue {
            print("\n\(message) [\(defaultValue)]: ", terminator: "")
        } else {
            print("\n\(message): ", terminator: "")
        }
        fflush(stdout)

        guard let input = readLine() else {
            throw TUIError.inputFailed
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, let defaultValue = defaultValue {
            return defaultValue
        }

        return trimmed
    }

    func promptSecure(_ message: String) async throws -> String {
        print("\n\(message)")
        print("(input will be hidden): ", terminator: "")
        fflush(stdout)

        // Note: For true secure input, we'd need termios/ncurses
        // For now, using standard input with a warning
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            throw TUIError.inputFailed
        }

        return input
    }

    func confirm(_ message: String, default defaultValue: Bool = false) async throws -> Bool {
        let defaultStr = defaultValue ? "Y/n" : "y/N"
        print("\n\(message) [\(defaultStr)]: ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return defaultValue
        }

        if input.isEmpty {
            return defaultValue
        }

        return input.hasPrefix("y")
    }

    func showSpinner(_ message: String) {
        currentSpinner?.cancel()

        currentSpinner = Task {
            let spinnerChars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            var index = 0

            while !Task.isCancelled {
                print("\r  \(spinnerChars[index]) \(message)", terminator: "")
                fflush(stdout)
                index = (index + 1) % spinnerChars.count
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    func hideSpinner() {
        currentSpinner?.cancel()
        currentSpinner = nil
        print("\r\u{1B}[K", terminator: "") // Clear line
        fflush(stdout)
    }

    func showProgress(_ message: String, current: Int, total: Int) {
        let percentage = total > 0 ? (current * 100) / total : 0
        let barWidth = 40
        let filled = (percentage * barWidth) / 100
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barWidth - filled)

        print("\r  \(message) [\(bar)] \(percentage)%", terminator: "")
        fflush(stdout)

        if current >= total {
            print() // New line when complete
        }
    }

    func updateProgress(current: Int, total: Int) {
        let percentage = total > 0 ? (current * 100) / total : 0
        let barWidth = 40
        let filled = (percentage * barWidth) / 100
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barWidth - filled)

        print("\r  [\(bar)] \(percentage)%", terminator: "")
        fflush(stdout)

        if current >= total {
            print() // New line when complete
        }
    }

    func showBenchmarkResults(_ results: BenchmarkResults) {
        print("\n┌─────────────────────────────────────────────────────────┐")
        print("│ System Benchmark Results                                │")
        print("├─────────────────────────────────────────────────────────┤")
        print("│ CPU:                                                    │")
        print("│   Model: \(results.cpu.model.prefix(45).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│   Cores: \(String(results.cpu.cores).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│   Arch:  \(results.cpu.architecture.padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│                                                         │")
        print("│ Memory:                                                 │")
        print("│   Total: \(String(format: "%.1f GB", results.memory.totalGB).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│   Speed: \(String(format: "%.1f GB/s", results.memory.bandwidthGBps).padding(toLength: 45, withPad: " ", startingAt: 0)) │")

        if let gpu = results.gpu {
            print("│                                                         │")
            print("│ GPU:                                                    │")
            print("│   Model: \(gpu.model.prefix(45).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
            print("│   VRAM:  \(String(format: "%.1f GB", gpu.memoryGB).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        }

        print("│                                                         │")
        print("│ Disk:                                                   │")
        print("│   Free:  \(String(format: "%.1f GB", results.disk.availableGB).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│   Read:  \(String(format: "%.1f MB/s", results.disk.readSpeedMBps).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("│   Write: \(String(format: "%.1f MB/s", results.disk.writeSpeedMBps).padding(toLength: 45, withPad: " ", startingAt: 0)) │")
        print("└─────────────────────────────────────────────────────────┘\n")

        let tier = results.isHighEnd ? "High-End" : (results.isMidRange ? "Mid-Range" : "Budget")
        print("  System Tier: \(tier)")
    }

    func showOnboardingComplete() {
        print("""

        ╔═══════════════════════════════════════════════════════════╗
        ║                                                           ║
        ║              🎉  Setup Complete!  🎉                     ║
        ║                                                           ║
        ║     Anigma CLI is ready to assist with your code.        ║
        ║                                                           ║
        ║     Type 'anigma chat' to start a session                ║
        ║     Type 'anigma --help' for available commands          ║
        ║                                                           ║
        ╚═══════════════════════════════════════════════════════════╝

        """)
    }

    func clearScreen() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        fflush(stdout)
    }

    // MARK: - Streaming Chat UI

    func startChatSession() {
        clearScreen()
        print("""
        ╔═══════════════════════════════════════════════════════════╗
        ║                  Anigma Chat Session                      ║
        ║  Type your message, press Enter. Use /help for commands  ║
        ╚═══════════════════════════════════════════════════════════╝

        """)
    }

    func showUserMessage(_ message: String) {
        print("\n┌─ You ─────────────────────────────────────────────────────┐")
        let wrapped = wrapText(message, width: 58)
        for line in wrapped {
            print("│ \(line.padding(toLength: 58, withPad: " ", startingAt: 0)) │")
        }
        print("└────────────────────────────────────────────────────────────┘")
    }

    func startAssistantMessage() {
        print("\n┌─ Assistant ───────────────────────────────────────────────┐")
        print("│ ", terminator: "")
        fflush(stdout)
    }

    func streamToken(_ token: String) {
        // Stream tokens with line wrapping
        print(token, terminator: "")
        fflush(stdout)
    }

    func endAssistantMessage() {
        print("\n└────────────────────────────────────────────────────────────┘")
    }

    func showThinking() {
        print("\n┌─ Assistant ───────────────────────────────────────────────┐")
        print("│ 🤔 Thinking...", terminator: "")
        fflush(stdout)
    }

    func clearThinking() {
        print("\r│ \u{1B}[K", terminator: "")
        fflush(stdout)
    }

    func showCodeBlock(_ code: String, language: String = "swift") {
        print("\n┌─ Code (\(language)) ───────────────────────────────────────┐")
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let truncated = String(line.prefix(56))
            print("│ \(truncated.padding(toLength: 58, withPad: " ", startingAt: 0)) │")
        }
        print("└────────────────────────────────────────────────────────────┘")
    }

    func promptMultilineInput() async throws -> String {
        print("\n> ", terminator: "")
        fflush(stdout)

        var lines: [String] = []
        while let line = readLine() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty && !lines.isEmpty {
                break // Empty line ends input
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    func showChatCommand(_ command: String, description: String) {
        print("  /\(command.padding(toLength: 15, withPad: " ", startingAt: 0)) - \(description)")
    }

    func showChatHelp() {
        print("\n╔═══════════════════════════════════════════════════════════╗")
        print("║                   Available Commands                      ║")
        print("╚═══════════════════════════════════════════════════════════╝")
        showChatCommand("help", description: "Show this help message")
        showChatCommand("clear", description: "Clear chat history")
        showChatCommand("save", description: "Save conversation to file")
        showChatCommand("load", description: "Load conversation from file")
        showChatCommand("context", description: "Show current context size")
        showChatCommand("model", description: "Switch model")
        showChatCommand("exit", description: "End chat session")
        print()
    }

    func showContextInfo(tokens: Int, maxTokens: Int) {
        let percentage = (tokens * 100) / maxTokens
        let bar = progressBar(current: tokens, total: maxTokens, width: 30)
        print("\n  Context: [\(bar)] \(tokens)/\(maxTokens) tokens (\(percentage)%)")
    }

    private func wrapText(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""

        for word in text.split(separator: " ") {
            let testLine = currentLine.isEmpty ? String(word) : currentLine + " " + word
            if testLine.count <= width {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = String(word)
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }

    private func progressBar(current: Int, total: Int, width: Int) -> String {
        let filled = total > 0 ? (current * width) / total : 0
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }
}

enum TUIError: Error {
    case inputFailed
    case cancelled
}
