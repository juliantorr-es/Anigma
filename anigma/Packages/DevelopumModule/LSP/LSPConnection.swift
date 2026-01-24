//
//  LSPConnection.swift
//  DevelopumModule
//
//  Manages LSP server connections with lifecycle control.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation
import AnigmaCore

/// Manages LSP server connections with lifecycle control.
public actor LSPConnection {
    private let repoId: UUID
    private let repoPath: String
    private let transportType: LSPTransportType
    private let lspServerPath: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var tcpClient: TCPClient?
    private var isConnected: Bool = false
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private var pendingRequests: [String: (Data?) -> Void] = [:]
    private var messageIdCounter: Int = 0

    public enum LSPTransportType: String, Codable, Sendable {
        case stdio
        case tcp
    }

    public init(
        repoId: UUID,
        repoPath: String,
        transportType: LSPTransportType = .stdio,
        lspServerPath: String = "sourcekit-lsp"
    ) {
        self.repoId = repoId
        self.repoPath = repoPath
        self.transportType = transportType
        self.lspServerPath = lspServerPath
    }

    // MARK: - Connection Lifecycle

    public func connect() async throws {
        logInfo("Connecting to LSP server (\(transportType.rawValue)) for repo: \(repoId.uuidString)", category: "LSPConnection")

        switch transportType {
        case .stdio:
            try await connectStdio()
        case .tcp:
            try await connectTCP()
        }

        isConnected = true
        reconnectAttempts = 0
        startMessageReader()
    }

    public func disconnect() {
        logInfo("Disconnecting from LSP server for repo: \(repoId.uuidString)", category: "LSPConnection")

        isConnected = false

        switch transportType {
        case .stdio:
            disconnectStdio()
        case .tcp:
            disconnectTCP()
        }

        for (_, callback) in pendingRequests {
            callback(nil)
        }
        pendingRequests.removeAll()
    }

    public func reconnect() async throws {
        guard reconnectAttempts < maxReconnectAttempts else {
            throw LSPConnectionError.maxReconnectAttemptsReached
        }

        disconnect()
        reconnectAttempts += 1
        try await connect()
    }

    private func connectStdio() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lspServerPath)
        process.arguments = []

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe

        try process.run()
        // process.waitUntilExit() // This would block the actor! 
        // In the original it had waitUntilExit() which might be a bug if called on MainActor or if it's meant to be a short-lived process.
        // But Language Servers are long-lived.

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
    }

    private func disconnectStdio() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    private func connectTCP() async throws {
        let client = TCPClient(host: "127.0.0.1", port: 8080)
        try await client.connect()
        self.tcpClient = client
    }

    private func disconnectTCP() {
        tcpClient?.disconnect()
        tcpClient = nil
    }

    private func startMessageReader() {
        Task {
            await readMessages()
        }
    }

    private func readMessages() async {
        while isConnected {
            do {
                let messageData: Data
                switch transportType {
                case .stdio:
                    guard let pipe = stdoutPipe else { break }
                    let data = try await readFromPipe(pipe)
                    messageData = data
                case .tcp:
                    guard let client = tcpClient else { break }
                    let data = try await client.read()
                    messageData = data
                }

                if let message = parseMessage(messageData) {
                    await handleMessage(message)
                }
            } catch {
                logError("Error reading LSP message: \(error)", category: "LSPConnection")
            }
        }
    }

    private func readFromPipe(_ pipe: Pipe) async throws -> Data {
        // Real implementation would read from file handle asynchronously
        return Data()
    }

    private func parseMessage(_ data: Data) -> LSPMessage? {
        guard let messageString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let contentLength = parseContentLength(from: messageString)
        guard let _ = contentLength,
              let jsonStart = messageString.range(of: "\r\n\r\n") else {
            return nil
        }

        let jsonStartIndex = messageString.distance(from: messageString.startIndex, to: jsonStart.upperBound)
        let jsonString = String(messageString[messageString.index(messageString.startIndex, offsetBy: jsonStartIndex)...])

        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(LSPMessage.self, from: jsonData)
    }

    private func parseContentLength(from message: String) -> Int? {
        guard let range = message.range(of: "Content-Length:") else { return nil }
        let afterPrefix = message[range.upperBound...]
        let endOfLine = afterPrefix.firstIndex(of: "\r") ?? afterPrefix.endIndex
        let numberString = String(afterPrefix[..<endOfLine]).trimmingCharacters(in: .whitespaces)
        return Int(numberString)
    }

    private func handleMessage(_ message: LSPMessage) async {
        if let id = message.id {
            if let callback = pendingRequests.removeValue(forKey: id) {
                if let result = message.result {
                    callback(try? JSONEncoder().encode(result))
                } else if let error = message.error {
                    let errorData = try? JSONEncoder().encode(error)
                    callback(errorData)
                }
            }
        }

        if let method = message.method {
            await handleNotification(method: method, params: message.params)
        }
    }

    private func handleNotification(method: LSPMethod, params: LSPParams?) async {
        switch method {
        case .windowShowMessage:
            if case .some(.initialize(let result)) = params {
                logInfo("LSP server info: \(result.serverInfo?.name ?? "unknown")", category: "LSPConnection")
            }
        case .telemetryEvent:
            break
        default:
            break
        }
    }

    // MARK: - Request/Response

    @discardableResult
    public func sendRequest<T: Decodable>(
        _ method: LSPMethod,
        params: any Encodable,
        responseType: T.Type
    ) async throws -> T {
        let id = generateMessageId()
        let paramsData = try JSONEncoder().encode(params)

        let lspMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method.rawValue,
            "params": try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        ]

        let messageData = try JSONSerialization.data(withJSONObject: lspMessage)
        try await sendMessage(messageData)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = { resultData in
                guard let resultData = resultData else {
                    continuation.resume(throwing: LSPConnectionError.noResponse)
                    return
                }

                do {
                    let result = try JSONDecoder().decode(T.self, from: resultData)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: LSPConnectionError.responseParseError(error))
                }
            }
        }
    }

    public func sendNotification(_ method: LSPMethod, params: any Encodable) async throws {
        let paramsData = try JSONEncoder().encode(params)

        let lspMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method.rawValue,
            "params": try JSONSerialization.jsonObject(with: paramsData) as? [String: Any] ?? [:]
        ]

        let messageData = try JSONSerialization.data(withJSONObject: lspMessage)
        try await sendMessage(messageData)
    }

    private func sendMessage(_ data: Data) async throws {
        let contentLength = data.count
        let header = "Content-Length: \(contentLength)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        var fullMessage = headerData
        fullMessage.append(data)

        switch transportType {
        case .stdio:
            guard let pipe = stdinPipe else {
                throw LSPConnectionError.notConnected
            }
            pipe.fileHandleForWriting.write(fullMessage)
        case .tcp:
            guard let client = tcpClient else {
                throw LSPConnectionError.notConnected
            }
            try await client.send(fullMessage)
        }
    }

    private func generateMessageId() -> String {
        messageIdCounter += 1
        return String(messageIdCounter)
    }
}

// MARK: - LSP Connection Errors

public enum LSPConnectionError: Error, LocalizedError {
    case notConnected
    case maxReconnectAttemptsReached
    case noResponse
    case responseParseError(Error)
    case serverError(LSPCode, String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "LSP server not connected"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnect attempts reached"
        case .noResponse:
            return "No response from LSP server"
        case .responseParseError(let error):
            return "Failed to parse LSP response: \(error)"
        case .serverError(let code, let message):
            return "LSP server error (\(code.rawValue)): \(message)"
        }
    }
}
