import Foundation

/// Configuration for the Gemini-MCP bridge
public struct BridgeConfig: Sendable, Codable {
    public let mcpBinaryPath: String?

    public init(mcpBinaryPath: String? = nil) {
        self.mcpBinaryPath = mcpBinaryPath
    }
}

/// Simplified MCP Client - communicates with anigma-mcp subprocess via JSON-RPC
actor MCPClient {
    static let shared = MCPClient()

    private let config: BridgeConfig
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var requestId: Int = 0
    private var listeningTask: Task<Void, Never>?
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]

    init(config: BridgeConfig = BridgeConfig()) {
        self.config = config
    }

    private var mcpBinaryPath: String {
        // 1. Explicit config path
        if let configPath = config.mcpBinaryPath, FileManager.default.fileExists(atPath: configPath) {
            return configPath
        }

        // 2. Env var
        if let envPath = ProcessInfo.processInfo.environment["ANIGMA_MCP_PATH"], FileManager.default.fileExists(atPath: envPath) {
            return envPath
        }

        // 3. Fallback to expected locations
        let candidates = [
            // Relative to build dir (approximate)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/release/anigma-mcp").path,
            "/usr/local/bin/anigma-mcp",
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin/anigma-mcp").path
        ]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return "/usr/local/bin/anigma-mcp" // Default fallback
    }

    /// Start the MCP subprocess
    func start() async throws {
        guard process == nil || process?.isRunning == false else { return }

        let process = Process()
        let executablePath = mcpBinaryPath
        print("🚀 Starting MCP binary at: \(executablePath)")
        process.executableURL = URL(fileURLWithPath: executablePath)

        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        // process.standardError = Pipe() // Let stderr flow to console for debug

        var env = ProcessInfo.processInfo.environment
        env["ANIGMA_MCP_ENABLE"] = "true"
        // env["ANIGMA_LOG_LEVEL"] = "debug"
        process.environment = env

        do {
            try process.run()
            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe

            // Start background listener
            startListening(outputPipe: outputPipe)

            print("✅ MCP subprocess started (PID: \(process.processIdentifier))")
        } catch {
            throw BridgeError.mcpStartFailed(error.localizedDescription)
        }
    }

    private func startListening(outputPipe: Pipe) {
        listeningTask?.cancel()
        listeningTask = Task {
            let fileHandle = outputPipe.fileHandleForReading
            do {
                // Use the AsyncSequence of bytes to read lines safely
                for try await lineData in fileHandle.bytes.lines.compactMap({ $0.data(using: .utf8) }) {
                    await self.handleIncomingData(lineData)
                }
            } catch {
                print("🛑 MCP listener error: \(error)")
            }
            print("🛑 MCP listener stopped")
        }
    }

    private func handleIncomingData(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let rawString = String(data: data, encoding: .utf8) {
                print("⚠️ [MCP] Failed to parse JSON: \(rawString)")
            }
            return
        }
        handleMessage(json)
    }

    private func handleMessage(_ message: [String: Any]) {
        // Handle Request/Response correlation
        if let id = message["id"] as? Int {
            if let continuation = pendingRequests.removeValue(forKey: id) {
                if let error = message["error"] as? [String: Any] {
                    continuation.resume(throwing: BridgeError.mcpError(error["message"] as? String ?? "Unknown error"))
                } else {
                    continuation.resume(returning: message)
                }
            }
        } else {
            // Notification or other message
            // print("🔔 [MCP] Notification: \(message)")
        }
    }

    /// List all tools from MCP
    func listTools() async throws -> [String: AnyCodable] {
        try await start()

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextRequestId(),
            "method": "tools/list"
        ]

        let response = try await sendRequest(request)
        return try convertToolsToGemini(response)
    }

    /// Call a tool
    func callTool(name: String, arguments: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        try await start()

        var jsonArgs: [String: Any] = [:]
        for (key, value) in arguments {
            jsonArgs[key] = value.value
        }

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextRequestId(),
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": jsonArgs
            ]
        ]

        let response = try await sendRequest(request)
        return try convertToolResponseToGemini(name: name, response: response)
    }

    // MARK: - Private

    private func sendRequest(_ request: [String: Any]) async throws -> [String: Any] {
        guard let inputPipe = inputPipe,
              let process = process,
              process.isRunning else {
            throw BridgeError.mcpNotRunning
        }

        guard let id = request["id"] as? Int else {
             throw BridgeError.invalidResponse("Request missing ID")
        }

        // Serialize request to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: request)
        var jsonWithNewline = jsonData
        jsonWithNewline.append(contentsOf: "\n".utf8)

        // Create continuation BEFORE sending to avoid race condition where response comes fast
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingRequests[id] = continuation

            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: jsonWithNewline)
            } catch {
                self.pendingRequests.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }

    private func convertToolsToGemini(_ response: [String: Any]) throws -> [String: AnyCodable] {
        guard let result = response["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]] else {
            return ["function_declarations": AnyCodable([])]
        }

        var functionDeclarations: [[String: AnyCodable]] = []

        for tool in tools {
            if let name = tool["name"] as? String,
               let description = tool["description"] as? String {
                let parameters = tool["inputSchema"] as? [String: Any] ?? [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]

                functionDeclarations.append([
                    "name": AnyCodable(name),
                    "description": AnyCodable(description),
                    "parameters": AnyCodable(parameters)
                ])
            }
        }

        return ["function_declarations": AnyCodable(functionDeclarations)]
    }

    private func convertToolResponseToGemini(
        name: String,
        response: [String: Any]
    ) throws -> [String: AnyCodable] {
        guard let result = response["result"] as? [String: Any] else {
            return [
                "name": AnyCodable(name),
                "response": AnyCodable(["content": "", "success": false])
            ]
        }

        let isError = (result["isError"] as? Bool) ?? false
        let contentArray = (result["content"] as? [[String: Any]]) ?? []

        var content = ""
        for item in contentArray {
            if let text = item["text"] as? String {
                content = text
                break
            }
        }

        return [
            "name": AnyCodable(name),
            "response": AnyCodable([
                "content": content,
                "success": !isError
            ])
        ]
    }

    private func nextRequestId() -> Int {
        requestId += 1
        return requestId
    }
}

// MARK: - Helper Types

enum BridgeError: Error, CustomStringConvertible {
    case mcpStartFailed(String)
    case mcpNotRunning
    case mcpError(String)
    case invalidResponse(String)
    case timeout(String)

    var description: String {
        switch self {
        case .mcpStartFailed(let msg): return "Failed to start MCP: \(msg)"
        case .mcpNotRunning: return "MCP subprocess is not running"
        case .mcpError(let msg): return "MCP error: \(msg)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .timeout(let msg): return "Timeout: \(msg)"
        }
    }
}

/// Type-erased Codable value
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        } else if let codable = value as? AnyCodable {
             try codable.encode(to: encoder)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value"))
        }
    }
}
