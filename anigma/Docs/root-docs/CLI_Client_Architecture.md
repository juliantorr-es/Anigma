# Anigma Thin CLI Client Architecture

## Overview

The Anigma CLI client is a thin client that communicates with the Anigma daemon via the protocol defined in `CLI_Daemon_Protocol_Specification.md`. This document outlines the architecture of the CLI client.

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Command Line Interface                    │
├─────────────────────────────────────────────────────────────┤
│  ArgumentParser Layer                                       │
│  • Command parsing and validation                           │
│  • Help text generation                                     │
│  • Subcommand routing                                       │
├─────────────────────────────────────────────────────────────┤
│  Command Handler Layer                                      │
│  • Business logic for each command                          │
│  • Input validation and transformation                      │
│  • Output formatting decisions                              │
├─────────────────────────────────────────────────────────────┤
│  Protocol Layer                                             │
│  • DaemonClient (SidecarBridge wrapper)                     │
│  • Request/Response serialization                           │
│  • Error handling and retries                               │
│  • Connection management                                    │
├─────────────────────────────────────────────────────────────┤
│  Formatter Layer                                            │
│  • Text, JSON, Table, Markdown output                       │
│  • Progress bars and spinners                               │
│  • Color and styling                                        │
├─────────────────────────────────────────────────────────────┤
│  Integration Layer                                          │
│  • Local filesystem operations                              │
│  • Configuration management                                 │
│  • Cache management                                         │
│  • Environment variable handling                            │
└─────────────────────────────────────────────────────────────┘
```

## 2. Core Components

### 2.1 DaemonClient

```swift
/// Main client for communicating with the daemon
public actor DaemonClient {
    private let bridge: SidecarBridge
    private let config: CLIConfiguration
    private let cache: ResponseCache
    private let retryPolicy: RetryPolicy
    
    init(config: CLIConfiguration) async throws {
        self.config = config
        self.bridge = try await SidecarBridge.create(
            socketPath: config.daemonSocketPath,
            clientName: "anigma-cli",
            scopes: config.requestedScopes
        )
        self.cache = InMemoryCache()
        self.retryPolicy = ExponentialBackoffRetryPolicy()
    }
    
    /// Execute a request with retry logic
    func execute<T: Codable, R: Codable>(
        _ request: DaemonRequest<T>
    ) async throws -> DaemonResponse<R> {
        for attempt in 1...retryPolicy.maxAttempts {
            do {
                return try await bridge.request(request)
            } catch {
                if retryPolicy.shouldRetry(error: error, attempt: attempt) {
                    let delay = retryPolicy.delayBeforeRetry(attempt: attempt)
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                throw error
            }
        }
        throw DaemonClientError.maxRetriesExceeded
    }
    
    /// Stream events from daemon
    func streamEvents<T: Codable>(
        _ request: DaemonRequest<T>
    ) -> AsyncThrowingStream<ServerEvent, Error> {
        // Implementation for SSE streaming
    }
}
```

### 2.2 Command Handlers

```swift
/// Base protocol for all command handlers
protocol CLICommandHandler {
    associatedtype Input
    associatedtype Output
    
    /// Validate and transform CLI arguments
    func validateAndTransform(_ args: [String]) throws -> Input
    
    /// Execute command against daemon
    func execute(input: Input, client: DaemonClient) async throws -> Output
    
    /// Format output for display
    func format(output: Output, format: OutputFormat) -> String
}

/// Chat command handler
struct ChatCommandHandler: CLICommandHandler {
    struct Input {
        let message: String
        let model: String?
        let temperature: Double?
        let sessionId: String?
    }
    
    struct Output {
        let response: String
        let modelUsed: String
        let tokensUsed: Int
    }
    
    func validateAndTransform(_ args: [String]) throws -> Input {
        // Parse arguments, validate ranges, etc.
    }
    
    func execute(input: Input, client: DaemonClient) async throws -> Output {
        let request = DaemonRequest(
            endpoint: "/ml/chat",
            method: .post,
            body: ChatRequest(
                messages: [ChatMessage(role: .user, content: input.message)],
                model: input.model,
                temperature: input.temperature,
                sessionId: input.sessionId
            )
        )
        
        let response: ChatResponse = try await client.execute(request)
        return Output(
            response: response.message,
            modelUsed: response.modelUsed,
            tokensUsed: response.tokensUsed
        )
    }
    
    func format(output: Output, format: OutputFormat) -> String {
        switch format {
        case .text:
            return output.response
        case .json:
            let json = [
                "response": output.response,
                "model": output.modelUsed,
                "tokens": output.tokensUsed
            ]
            return try! JSONEncoder().encode(json)
        case .markdown:
            return "**Response**: \(output.response)\n\n*Model: \(output.modelUsed), Tokens: \(output.tokensUsed)*"
        }
    }
}
```

### 2.3 Output Formatters

```swift
enum OutputFormat: String, CaseIterable {
    case text
    case json
    case table
    case markdown
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .table: return "txt"
        case .markdown: return "md"
        }
    }
}

protocol OutputFormatter {
    func format<T>(_ value: T) -> String
}

struct TextFormatter: OutputFormatter {
    func format<T>(_ value: T) -> String {
        // Simple string representation
        return String(describing: value)
    }
}

struct JSONFormatter: OutputFormatter {
    func format<T>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }
}

struct TableFormatter: OutputFormatter {
    func format<T>(_ value: T) -> String {
        // Create ASCII table
        // Detect if value is array or single object
        // Generate appropriate table
    }
}

struct ProgressFormatter {
    func formatIndeterminate(message: String) -> String {
        let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        let frame = frames[Int(Date().timeIntervalSince1970 * 10) % frames.count]
        return "\(frame) \(message)"
    }
    
    func formatDeterminate(progress: Double, total: Double, unit: String = "") -> String {
        let percent = Int((progress / total) * 100)
        let bars = Int((progress / total) * 20)
        let bar = String(repeating: "█", count: bars) + 
                  String(repeating: "░", count: 20 - bars)
        return "\(bar) \(percent)% (\(progress)\(unit)/\(total)\(unit))"
    }
}
```

### 2.4 Configuration Management

```swift
class CLIConfiguration {
    private let fileURL: URL
    private var config: [String: Any]
    
    static func shared() async throws -> CLIConfiguration {
        // Singleton with async initialization
    }
    
    func get<T>(_ key: String, defaultValue: T) -> T {
        return config[key] as? T ?? defaultValue
    }
    
    func set<T>(_ key: String, value: T) async throws {
        config[key] = value
        try await save()
    }
    
    func getDaemonSocketPath() -> String {
        return get("daemon.socketPath", defaultValue: "/tmp/anigma-daemon.sock")
    }
    
    func getRequestedScopes() -> [String] {
        return get("auth.scopes", defaultValue: [
            "job.submit", "job.status", "vault.read", "vault.write",
            "models.list", "ml.chat", "config.read"
        ])
    }
    
    func getOutputFormat() -> OutputFormat {
        let formatString: String = get("output.format", defaultValue: "text")
        return OutputFormat(rawValue: formatString) ?? .text
    }
}
```

## 3. Command Implementation Examples

### 3.1 Chat Command

```swift
struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start an interactive chat session",
        discussion: """
        Starts an interactive chat session with the configured AI model.
        
        Examples:
          anigma chat
          anigma chat --model gpt-4
          anigma chat --temperature 0.8
        """
    )
    
    @Option(name: .shortAndLong, help: "Model to use for chat")
    var model: String?
    
    @Option(name: .shortAndLong, help: "Temperature (0.0 to 2.0)")
    var temperature: Double?
    
    @Flag(name: .long, help: "Skip onboarding check")
    var skipOnboarding = false
    
    @Flag(name: .long, help: "Stream responses")
    var stream = false
    
    func run() async throws {
        let config = try await CLIConfiguration.shared()
        let client = try await DaemonClient(config: config)
        let formatter = OutputFormatterFactory.create(config.getOutputFormat())
        
        // Check onboarding if needed
        if !skipOnboarding {
            let status = try await client.getOnboardingStatus()
            if !status.isOnboarded {
                print("Please run 'anigma init' first")
                return
            }
        }
        
        // Start interactive session
        let chatUI = ChatInterface(client: client, formatter: formatter)
        try await chatUI.run(
            initialModel: model,
            temperature: temperature,
            stream: stream
        )
    }
}
```

### 3.2 Job Command

```swift
struct JobCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage AI jobs",
        subcommands: [Submit.self, Status.self, List.self, Cancel.self]
    )
    
    struct Submit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Submit a new job"
        )
        
        @Argument(help: "Job specification file or JSON")
        var spec: String
        
        @Option(name: .long, help: "Output format")
        var format: OutputFormat = .text
        
        @Flag(name: .long, help: "Follow job progress")
        var follow = false
        
        func run() async throws {
            let config = try await CLIConfiguration.shared()
            let client = try await DaemonClient(config: config)
            
            // Parse job spec
            let jobSpec = try parseJobSpec(spec)
            
            // Submit job
            let response = try await client.submitJob(jobSpec)
            
            // Format output
            let output = JobSubmitOutput(
                jobId: response.jobId,
                receiptHash: response.receiptHash,
                estimatedQueueTime: response.estimatedQueueTime
            )
            
            let formatter = OutputFormatterFactory.create(format)
            print(formatter.format(output))
            
            // Follow progress if requested
            if follow {
                try await followJobProgress(jobId: response.jobId, client: client)
            }
        }
        
        private func followJobProgress(jobId: String, client: DaemonClient) async throws {
            let progress = ProgressFormatter()
            let stream = client.streamJobEvents(jobId: jobId)
            
            for try await event in stream {
                switch event.type {
                case .state:
                    print(progress.formatIndeterminate(message: "State: \(event.message)"))
                case .progress:
                    let percent = Double(event.progressPermille) / 10.0
                    print(progress.formatDeterminate(progress: percent, total: 100, unit: "%"))
                case .output:
                    print("Output: \(event.message)")
                case .complete:
                    print("✓ Job completed")
                    return
                case .error:
                    print("✗ Job failed: \(event.message)")
                    return
                }
            }
        }
    }
}
```

### 3.3 Models Command

```swift
struct ModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage AI models",
        subcommands: [List.self, Install.self, Uninstall.self, Recommend.self]
    )
    
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List installed models"
        )
        
        @Option(name: .long, help: "Output format")
        var format: OutputFormat = .table
        
        func run() async throws {
            let config = try await CLIConfiguration.shared()
            let client = try await DaemonClient(config: config)
            
            let response = try await client.listModels()
            let formatter = OutputFormatterFactory.create(format)
            
            if format == .table {
                // Create table with columns
                let table = createModelTable(response.models)
                print(table)
            } else {
                print(formatter.format(response))
            }
        }
        
        private func createModelTable(_ models: [ModelInfo]) -> String {
            var table = "┌─────────────────┬──────────┬────────┬──────────────┬─────────────────────┐\n"
            table += "│ Name            │ Type     │ Size   │ Quantization │ Installed           │\n"
            table += "├─────────────────┼──────────┼────────┼──────────────┼─────────────────────┤\n"
            
            for model in models {
                let name = model.name.padding(toLength: 15, withPad: " ", startingAt: 0)
                let type = model.type.padding(toLength: 8, withPad: " ", startingAt: 0)
                let size = String(format: "%.1f GB", model.sizeGB).padding(toLength: 6, withPad: " ", startingAt: 0)
                let quant = model.quantization.padding(toLength: 12, withPad: " ", startingAt: 0)
                let date = model.installedAt?.formatted(date: .abbreviated, time: .shortened) ?? "N/A"
                let dateStr = date.padding(toLength: 19, withPad: " ", startingAt: 0)
                
                table += "│ \(name) │ \(type) │ \(size) │ \(quant) │ \(dateStr) │\n"
            }
            
            table += "└─────────────────┴──────────┴────────┴──────────────┴─────────────────────┘"
            return table
        }
    }
}
```

## 4. File System Integration

### 4.1 File Upload/Download

```swift
class FileTransferManager {
    private let client: DaemonClient
    private let chunkSize: Int = 1024 * 1024 // 1MB chunks
    
    func uploadFile(at path: String, metadata: [String: String] = [:]) async throws -> String {
        let fileURL = URL(fileURLWithPath: path)
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize!
        
        let progress = ProgressFormatter()
        print(progress.formatDeterminate(progress: 0, total: Double(fileSize), unit: "B"))
        
        // Read file in chunks
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        
        var offset = 0
        var hash: String?
        
        while offset < fileSize {
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            
            let request = UploadChunkRequest(
                data: chunk,
                offset: offset,
                totalSize: fileSize,
                metadata: metadata
            )
            
            let response: UploadChunkResponse = try await client.execute(
                DaemonRequest(endpoint: "/artifacts/upload", method: .post, body: request)
            )
            
            hash = response.hash
            offset += chunk.count
            
            // Update progress
            print(progress.formatDeterminate(
                progress: Double(offset),
                total: Double(fileSize),
                unit: "B"
            ))
        }
        
        guard let finalHash = hash else {
            throw FileTransferError.uploadFailed
        }
        
        return finalHash
    }
    
    func downloadFile(hash: String, to path: String) async throws {
        let fileURL = URL(fileURLWithPath: path)
        
        // Get file info first
        let infoRequest = DaemonRequest(
            endpoint: "/artifacts/info",
            method: .post,
            body: ["hash": hash]
        )
        let info: ArtifactInfo = try await client.execute(infoRequest)
        
        let progress = ProgressFormatter()
        print(progress.formatDeterminate(progress: 0, total: Double(info.sizeBytes), unit: "B"))
        
        // Download in chunks
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        
        var offset = 0
        while offset < info.sizeBytes {
            let request = DownloadChunkRequest(
                hash: hash,
                offset: offset,
                length: min(chunkSize, info.sizeBytes - offset)
            )
            
            let response: DownloadChunkResponse = try await client.execute(
                DaemonRequest(endpoint: "/artifacts/download", method: .post, body: request)
            )
            
            try handle.write(contentsOf: response.data)
            offset += response.data.count
            
            // Update progress
            print(progress.formatDeterminate(
                progress: Double(offset),
                total: Double(info.sizeBytes),
                unit: "B"
            ))
        }
    }
}
```

### 4.2 Workspace Management

```swift
class WorkspaceManager {
    private let client: DaemonClient
    private let watcher: FileWatcher
    
    func syncWorkspace(path: String, patterns: [String] = ["**"]) async throws {
        let fileManager = FileManager.default
        let workspaceURL = URL(fileURLWithPath: path)
        
        // Find all files matching patterns
        let enumerator = fileManager.enumerator(
            at: workspaceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        var filesToSync: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if matchesPatterns(fileURL, patterns: patterns) {
                filesToSync.append(fileURL)
            }
        }
        
        // Sync each file
        let progress = ProgressFormatter()
        for (index, fileURL) in filesToSync.enumerated() {
            let relativePath = fileURL.relativePath(from: workspaceURL)
            print(progress.formatIndeterminate(
                message: "Syncing \(relativePath) (\(index + 1)/\(filesToSync.count))"
            ))
            
            try await syncFile(fileURL, relativePath: relativePath)
        }
        
        print("✓ Synced \(filesToSync.count) files")
    }
    
    func watchWorkspace(path: String, patterns: [String] = ["**"]) async throws {
        watcher.startWatching(path: path) { event in
            if matchesPatterns(event.url, patterns: patterns) {
                Task {
                    try await self.syncFile(event.url)
                }
            }
        }
    }
}
```

## 5. Error Handling and Recovery

### 5.1 Error Types

```swift
enum CLIError: Error, LocalizedError {
    case daemonUnavailable
    case authenticationFailed
    case insufficientScope(String)
    case fileNotFound(String)
    case invalidInput(String)
    case networkError(Error)
    case rateLimited(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .daemonUnavailable:
            return "Anigma daemon is not running. Start it with 'anigmad'"
        case .authenticationFailed:
            return "Authentication failed. Please run 'anigma init'"
        case .insufficientScope(let scope):
            return "Insufficient permissions. Required scope: \(scope)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Try again in \(Int(retryAfter)) seconds"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .daemonUnavailable:
            return "Run 'anigmad' in another terminal or check if it's installed"
        case .authenticationFailed:
            return "Run 'anigma init' to configure authentication"
        case .insufficientScope:
            return "Contact your administrator to request additional permissions"
        case .fileNotFound:
            return "Check the file path and permissions"
        case .invalidInput:
            return "Check command syntax with 'anigma --help'"
        case .networkError:
            return "Check your network connection and daemon status"
        case .rateLimited:
            return "Wait before trying again or reduce request frequency"
        }
    }
}
```

### 5.2 Error Recovery

```swift
class ErrorRecovery {
    static func handle(_ error: Error, command: String) async -> Bool {
        switch error {
        case let cliError as CLIError:
            print("Error: \(cliError.localizedDescription)")
            if let suggestion = cliError.recoverySuggestion {
                print("Suggestion: \(suggestion)")
            }
            return false
            
        case let daemonError as DaemonError:
            switch daemonError.code {
            case "INVALID_TOKEN":
                print("Session expired. Re-authenticating...")
                return await reauthenticate()
                
            case "RATE_LIMITED":
                let retryAfter = daemonError.data?["retryAfter"] as? TimeInterval ?? 5.0
                print("Rate limited. Waiting \(retryAfter) seconds...")
                try? await Task.sleep(for: .seconds(retryAfter))
                return true // Retry
                
            default:
                print("Daemon error: \(daemonError.message)")
                return false
            }
            
        default:
            print("Unexpected error: \(error.localizedDescription)")
            return false
        }
    }
    
    private static func reauthenticate() async -> Bool {
        // Try to re-establish session
        // Clear cached tokens
        // Prompt for re-authentication if needed
        return false // For now, require manual re-auth
    }
}
```

## 6. Performance Optimizations

### 6.1 Connection Pooling

```swift
actor ConnectionPool {
    private var connections: [HTTPClient] = []
    private var available: [HTTPClient] = []
    private let maxConnections: Int
    private let factory: () -> HTTPClient
    
    init(maxConnections: Int = 5, factory: @escaping () -> HTTPClient) {
        self.maxConnections = maxConnections
        self.factory = factory
    }
    
    func getConnection() async -> HTTPClient {
        if let connection = available.popLast() {
            return connection
        }
        
        if connections.count < maxConnections {
            let connection = factory()
            connections.append(connection)
            return connection
        }
        
        // Wait for a connection to become available
        return await withCheckedContinuation { continuation in
            Task {
                while available.isEmpty {
                    try await Task.sleep(for: .milliseconds(10))
                }
                let connection = available.removeFirst()
                continuation.resume(returning: connection)
            }
        }
    }
    
    func returnConnection(_ connection: HTTPClient) {
        available.append(connection)
    }
}
```

### 6.2 Response Caching

```swift
protocol ResponseCache {
    func get<T: Codable>(key: String) -> T?
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval)
    func invalidate(key: String)
    func clear()
}

class MemoryCache: ResponseCache {
    private var cache: [String: (data: Data, expires: Date)] = [:]
    private let queue = DispatchQueue(label: "com.anigma.cache", attributes: .concurrent)
    
    func get<T: Codable>(key: String) -> T? {
        queue.sync {
            guard let entry = cache[key], entry.expires > Date() else {
                cache.removeValue(forKey: key)
                return nil
            }
            return try? JSONDecoder().decode(T.self, from: entry.data)
        }
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            if let data = try? JSONEncoder().encode(value) {
                let expires = Date().addingTimeInterval(ttl)
                self.cache[key] = (data, expires)
            }
        }
    }
    
    func invalidate(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
```

### 6.3 Request Batching

```swift
class BatchProcessor {
    private let client: DaemonClient
    private var batch: [BatchRequest] = []
    private let batchSize: Int
    private let flushInterval: TimeInterval
    
    init(client: DaemonClient, batchSize: Int = 10, flushInterval: TimeInterval = 0.1) {
        self.client = client
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        startFlushTimer()
    }
    
    func addRequest(_ request: DaemonRequest<some Codable>) async throws -> some Codable {
        let batchRequest = BatchRequest(request: request)
        batch.append(batchRequest)
        
        if batch.count >= batchSize {
            try await flush()
        }
        
        return await batchRequest.response
    }
    
    private func flush() async throws {
        guard !batch.isEmpty else { return }
        
        let requestsToSend = batch
        batch.removeAll()
        
        let batchRequest = DaemonRequest(
            endpoint: "/batch",
            method: .post,
            body: BatchExecuteRequest(requests: requestsToSend.map { $0.request })
        )
        
        let response: BatchExecuteResponse = try await client.execute(batchRequest)
        
        // Match responses to original requests
        for (index, request) in requestsToSend.enumerated() {
            if index < response.responses.count {
                await request.fulfill(response.responses[index])
            } else {
                await request.fail(BatchError.missingResponse)
            }
        }
    }
}
```

## 7. Testing Strategy

### 7.1 Unit Tests

```swift
class CommandHandlerTests: XCTestCase {
    func testChatCommandValidation() async throws {
        let handler = ChatCommandHandler()
        let input = try handler.validateAndTransform(["Hello", "--model", "gpt-4"])
        XCTAssertEqual(input.message, "Hello")
        XCTAssertEqual(input.model, "gpt-4")
    }
    
    func testJobCommandExecution() async throws {
        let mockClient = MockDaemonClient()
        let handler = JobSubmitCommandHandler()
        
        let output = try await handler.execute(
            input: JobSubmitInput(spec: "test.json"),
            client: mockClient
        )
        
        XCTAssertNotNil(output.jobId)
        XCTAssertTrue(mockClient.submitJobWasCalled)
    }
}
```

### 7.2 Integration Tests

```swift
class CLIIntegrationTests: XCTestCase {
    var daemonProcess: Process?
    var client: DaemonClient?
    
    override func setUp() async throws {
        // Start test daemon
        daemonProcess = try await startTestDaemon()
        
        // Create client
        let config = TestConfiguration()
        client = try await DaemonClient(config: config)
    }
    
    override func tearDown() async throws {
        client = nil
        daemonProcess?.terminate()
    }
    
    func testChatWorkflow() async throws {
        let chatHandler = ChatCommandHandler()
        let input = try chatHandler.validateAndTransform(["Hello"])
        let output = try await chatHandler.execute(input: input, client: client!)
        
        XCTAssertFalse(output.response.isEmpty)
        XCTAssertNotNil(output.modelUsed)
    }
    
    func testFileUploadDownload() async throws {
        // Create test file
        let testFile = createTestFile()
        
        // Upload
        let hash = try await FileTransferManager(client: client!)
            .uploadFile(at: testFile.path)
        
        XCTAssertFalse(hash.isEmpty)
        
        // Download
        let downloadPath = testFile.path + ".downloaded"
        try await FileTransferManager(client: client!)
            .downloadFile(hash: hash, to: downloadPath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: downloadPath))
    }
}
```

### 7.3 End-to-End Tests

```swift
class EndToEndTests: XCTestCase {
    func testCompleteWorkflow() async throws {
        // 1. Initialize
        let initOutput = try await runCommand("anigma", "init", "--force")
        XCTAssertTrue(initOutput.contains("Configuration complete"))
        
        // 2. List models
        let modelsOutput = try await runCommand("anigma", "models", "list")
        XCTAssertTrue(modelsOutput.contains("Installed Models"))
        
        // 3. Start chat
        let chatProcess = try Process.runCommand("anigma", "chat", "--model", "test-model")
        
        // Send input
        try chatProcess.sendInput("Hello\n")
        
        // Get response
        let response = try await chatProcess.readOutput(timeout: 5)
        XCTAssertFalse(response.isEmpty)
        
        // 4. Submit job
        let jobOutput = try await runCommand("anigma", "job", "submit", "test-job.json")
        XCTAssertTrue(jobOutput.contains("Job submitted"))
        
        // 5. Check status
        let jobId = extractJobId(jobOutput)
        let statusOutput = try await runCommand("anigma", "job", "status", jobId)
        XCTAssertTrue(statusOutput.contains("Status:"))
    }
}
```

## 8. Deployment Considerations

### 8.1 Installation

```bash
# Installation script
#!/bin/bash

# Check dependencies
if ! command -v swift &> /dev/null; then
    echo "Swift not found. Please install Swift 5.9+"
    exit 1
fi

# Build CLI
echo "Building Anigma CLI..."
swift build -c release --product anigma-cli

# Install to /usr/local/bin
sudo cp .build/release/anigma-cli /usr/local/bin/anigma

# Create configuration directory
mkdir -p ~/.anigma

echo "Installation complete. Run 'anigma --help' to get started."
```

### 8.2 Configuration Migration

```swift
class ConfigurationMigrator {
    func migrateFromOldCLI() async throws {
        let oldConfigPath = "~/.anigma-old/config.json"
        let newConfigPath = "~/.anigma/config.json"
        
        if FileManager.default.fileExists(atPath: oldConfigPath) {
            print("Migrating configuration from old CLI...")
            
            let oldConfig = try loadOldConfig(at: oldConfigPath)
            let newConfig = convertToNewFormat(oldConfig)
            
            try saveConfig(newConfig, at: newConfigPath)
            print("✓ Configuration migrated")
        }
    }
    
    private func convertToNewFormat(_ old: OldConfig) -> NewConfig {
        return NewConfig(
            daemon: DaemonConfig(
                socketPath: old.daemonSocketPath ?? "/tmp/anigma-daemon.sock"
            ),
            auth: AuthConfig(
                scopes: old.requestedScopes ?? defaultScopes
            ),
            output: OutputConfig(
                format: old.outputFormat ?? "text"
            )
        )
    }
}
```

## 9. Future Extensions

### 9.1 Plugin System

```swift
protocol CLIPlugin {
    var name: String { get }
    var version: String { get }
    
    func registerCommands(with builder: CommandBuilder)
    func willExecuteCommand(_ command: String)
    func didExecuteCommand(_ command: String, result: Result<Any, Error>)
}

class PluginManager {
    private var plugins: [CLIPlugin] = []
    
    func loadPlugins(from directory: String) throws {
        let pluginFiles = try FileManager.default.contentsOfDirectory(
            atPath: directory
        ).filter { $0.hasSuffix(".anigmaplugin") }
        
        for file in pluginFiles {
            let plugin = try loadPlugin(at: "\(directory)/\(file)")
            plugins.append(plugin)
        }
    }
    
    func registerCommands(with builder: CommandBuilder) {
        for plugin in plugins {
            plugin.registerCommands(with: builder)
        }
    }
}
```

### 9.2 Scripting Support

```swift
class ScriptRunner {
    func runScript(_ script: String, context: ScriptContext) async throws {
        let lines = script.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.starts(with: "#") {
                continue
            }
            
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            let command = String(parts[0])
            let args = parts.count > 1 ? String(parts[1]) : ""
            
            try await executeCommand(command, args: args, context: context)
        }
    }
    
    private func executeCommand(_ command: String, args: String, context: ScriptContext) async throws {
        switch command {
        case "chat":
            let response = try await context.client.chat(message: args)
            context.output(response)
        case "submit":
            let jobId = try await context.client.submitJob(spec: args)
            context.output("Job submitted: \(jobId)")
        case "wait":
            let seconds = Double(args) ?? 1.0
            try await Task.sleep(for: .seconds(seconds))
        default:
            throw ScriptError.unknownCommand(command)
        }
    }
}
```

This architecture provides a solid foundation for the thin CLI client that can efficiently communicate with the daemon while providing a great user experience.