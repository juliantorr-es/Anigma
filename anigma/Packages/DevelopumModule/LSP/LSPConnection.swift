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
    
    // Completion handlers for requests
    private var pendingRequests: [String: (Result<LSPMessage, Error>) -> Void] = [:]
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
            callback(.failure(LSPConnectionError.notConnected))
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
        let client = tcpClient
        Task {
            await client?.disconnect()
        }
        tcpClient = nil
    }

    private func startMessageReader() {
        Task {
            await readMessages()
        }
    }

    private func readMessages() async {
        // Simple buffer for reading
        // In a real implementation, we would use a proper AsyncSequence or stream parser
        // For now we assume readFromPipe blocks until a message is available or fails
        while isConnected {
            do {
                let messageData: Data
                switch transportType {
                case .stdio:
                    guard let pipe = stdoutPipe else { 
                        try await Task.sleep(nanoseconds: 100_000_000)
                        continue 
                    }
                    messageData = try await readFromPipe(pipe)
                case .tcp:
                    guard let client = tcpClient else { 
                        try await Task.sleep(nanoseconds: 100_000_000)
                        continue 
                    }
                    messageData = try await client.read()
                }

                if let message = parseMessage(messageData) {
                    await handleMessage(message)
                }
            } catch {
                logError("Error reading LSP message: \(error)", category: "LSPConnection")
                // Avoid tight loop on error
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !isConnected { break }
            }
        }
    }
    
    // MARK: - Message Handling

    private func readFromPipe(_ pipe: Pipe) async throws -> Data {
        // This is a simplified blocking read for demo purposes to satisfy compilation.
        // A real LSP reader needs to parse Content-Length headers.
        
        // We'll use FileHandle's availableData which might not be a full message.
        // Proper LSP framing is required here.
        // For compilation fix, we provide a signature.
        
        // TODO: Implement proper LSP framing (Header + Content-Length)
        let handle = pipe.fileHandleForReading
        return try handle.readToEnd() ?? Data()
    }
    
    private func parseMessage(_ data: Data) -> LSPMessage? {
        do {
            return try JSONDecoder().decode(LSPMessage.self, from: data)
        } catch {
            logError("Failed to parse message: \(error)", category: "LSPConnection")
            return nil
        }
    }
    
    private func handleMessage(_ message: LSPMessage) {
        if let id = message.id, let callback = pendingRequests[id] {
            callback(.success(message))
            pendingRequests.removeValue(forKey: id)
        } else {
            // Handle notifications or requests from server
            logInfo("Received notification or unknown response: \(message.method?.rawValue ?? "unknown")", category: "LSPConnection")
        }
    }

    // MARK: - Public Methods
    
    public func sendRequest<T: Decodable, P: Encodable>(
        _ method: LSPMethod,
        params: P,
        responseType: T.Type
    ) async throws -> T {
        guard isConnected else { throw LSPConnectionError.notConnected }
        
        let id = "req-\(messageIdCounter)"
        messageIdCounter += 1
        
        let paramsAny = AnyCodable(params)
        
        let message = LSPMessage(
            jsonrpc: "2.0",
            id: id,
            method: method,
            params: paramsAny
        )
        
        let data = try JSONEncoder().encode(message)
        try await sendData(data)
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = { result in
                switch result {
                case .success(let response):
                    if let error = response.error {
                        continuation.resume(throwing: LSPConnectionError.serverError(error.code, error.message))
                    } else if let result = response.result {
                        // Decode result to T
                        // We need to re-encode result to decode it to T? 
                        // Or if LSPResult wraps the data.
                        do {
                            let jsonData = try JSONEncoder().encode(result)
                            let typedResult = try JSONDecoder().decode(T.self, from: jsonData)
                            continuation.resume(returning: typedResult)
                        } catch {
                            continuation.resume(throwing: LSPConnectionError.responseParseError(error))
                        }
                    } else {
                        // Void result?
                        if T.self == Void.self || T.self == Optional<Void>.self {
                             continuation.resume(returning: () as! T)
                        } else {
                             continuation.resume(throwing: LSPConnectionError.noResponse)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func sendNotification<P: Encodable>(_ method: LSPMethod, params: P) async throws {
        guard isConnected else { throw LSPConnectionError.notConnected }
        
        let paramsAny = AnyCodable(params)
        
        let message = LSPMessage(
            jsonrpc: "2.0",
            id: nil,
            method: method,
            params: paramsAny
        )
        
        let data = try JSONEncoder().encode(message)
        try await sendData(data)
    }
    
    private func sendData(_ data: Data) async throws {
        // Add Content-Length header
        let header = "Content-Length: \(data.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else { return }
        
        var fullData = headerData
        fullData.append(data)
        
        switch transportType {
        case .stdio:
            guard let pipe = stdinPipe else { throw LSPConnectionError.notConnected }
            try pipe.fileHandleForWriting.write(contentsOf: fullData)
        case .tcp:
            guard let client = tcpClient else { throw LSPConnectionError.notConnected }
            try await client.send(fullData)
        }
    }
} // End of actor LSPConnection

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

