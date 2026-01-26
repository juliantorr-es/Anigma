import SwiftUI
import Foundation
import System
import Darwin
@preconcurrency import UserNotifications

// MARK: - Resource Monitoring

actor SystemMonitor {
    private var lastCPUInfo: host_cpu_load_info?
    private var lastUpdateTime: Date?
    
    struct SystemMetrics: Sendable, Codable {
        let cpuUsage: Double
        let memoryUsage: Double
        let diskIO: DiskIOMetrics
        let networkConnections: Int
        let uptime: TimeInterval
    }
    
    struct DiskIOMetrics: Sendable, Codable {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOps: UInt64
        let writeOps: UInt64
    }
    
    init() {
        self.lastUpdateTime = Date()
    }
    
    func getMetrics() -> SystemMetrics {
        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryUsage()
        let diskIO = getDiskIOMetrics()
        let networkConnections = getNetworkConnectionCount()
        let uptime = getUptime()
        
        return SystemMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskIO: diskIO,
            networkConnections: networkConnections,
            uptime: uptime
        )
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let userTicks = Double(cpuInfo.cpu_ticks.0)
        let systemTicks = Double(cpuInfo.cpu_ticks.1)
        let idleTicks = Double(cpuInfo.cpu_ticks.2)
        let niceTicks = Double(cpuInfo.cpu_ticks.3)
        
        let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
        
        if let last = lastCPUInfo {
            let lastUserTicks = Double(last.cpu_ticks.0)
            let lastSystemTicks = Double(last.cpu_ticks.1)
            let lastIdleTicks = Double(last.cpu_ticks.2)
            let lastNiceTicks = Double(last.cpu_ticks.3)
            let lastTotalTicks = lastUserTicks + lastSystemTicks + lastIdleTicks + lastNiceTicks
            
            let userDiff = userTicks - lastUserTicks
            let systemDiff = systemTicks - lastSystemTicks
            _ = idleTicks - lastIdleTicks
            let totalDiff = totalTicks - lastTotalTicks
            
            if totalDiff > 0 {
                let cpuUsage = ((userDiff + systemDiff) / totalDiff) * 100.0
                lastCPUInfo = cpuInfo
                return min(max(cpuUsage, 0.0), 100.0)
            }
        }
        
        lastCPUInfo = cpuInfo
        return 0.0
    }
    
    private func getMemoryUsage() -> Double {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let usedMemory = Double(taskInfo.phys_footprint)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        return (usedMemory / totalMemory) * 100.0
    }
    
    private func getDiskIOMetrics() -> DiskIOMetrics {
        // Simplified disk I/O metrics - return zeros for now
        // In a production system, you would use proper disk I/O monitoring
        return DiskIOMetrics(
            readBytes: 0,
            writeBytes: 0,
            readOps: 0,
            writeOps: 0
        )
    }
    
    private func getNetworkConnectionCount() -> Int {
        var connectionCount = 0
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return 0 }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let addr = ptr!.pointee.ifa_addr.pointee
            if addr.sa_family == AF_INET || addr.sa_family == AF_INET6 {
                connectionCount += 1
            }
            ptr = ptr!.pointee.ifa_next
        }
        
        return connectionCount
    }
    
    private func getUptime() -> TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }
}

// MARK: - Network Server

actor DaemonServer {
    private var serverTask: Task<Void, Never>?
    private var isRunning = false
    private let port: Int
    private let monitor: SystemMonitor
    private let jobRegistry: JobRegistry
    private let authMiddleware: AuthMiddleware
    
    init(port: Int = 8080, monitor: SystemMonitor, jobRegistry: JobRegistry, config: DaemonConfig) {
        self.port = port
        self.monitor = monitor
        self.jobRegistry = jobRegistry
        self.authMiddleware = AuthMiddleware(config: config)
    }
    
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        
        serverTask = Task {
            await runServer()
        }
    }
    
    func stop() async {
        isRunning = false
        serverTask?.cancel()
        serverTask = nil
    }
    
    func restart() async {
        await stop()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await start()
    }
    
    private func runServer() async {
        do {
            let listener = try await AsyncSocketListener(port: port)
            print("Daemon server started on port \(port)")
            
            for try await socket in listener.sockets {
                Task {
                    await handleConnection(socket)
                }
            }
        } catch {
            print("Server error: \(error)")
        }
    }
    
    private func handleConnection(_ socket: AsyncSocket) async {
        do {
            let request = try await socket.readRequest()
            let response = await handleRequest(request)
            try await socket.writeResponse(response)
            try await socket.close()
        } catch {
            print("Connection error: \(error)")
        }
    }
    
    private func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        // Check authentication
        if !authMiddleware.authenticate(request: request) {
            return authMiddleware.unauthorizedResponse()
        }
        
        switch request.path {
        case "/session/open":
            guard request.method.uppercased() == "POST",
                  let body = request.body else {
                return HTTPResponse(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(["error": "Invalid request"])
                )
            }
            
            // Simple session opening - in production this would validate scopes, etc.
            let sessionResponse: [String: String] = [
                "clientId": UUID().uuidString,
                "capabilityToken": Data(UUID().uuidString.utf8).base64EncodedString(),
                "sessionId": UUID().uuidString
            ]
            
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONEncoder().encode(sessionResponse)
            )
            
        case "/status":
            if request.method.uppercased() == "POST" {
                // SidecarBridge format
                let metrics = await monitor.getMetrics()
                let statusResponse: [String: Any] = [
                    "daemonVersion": "1.0.0",
                    "uptimeSeconds": Int(metrics.uptime),
                    "cpuUsagePercent": metrics.cpuUsage,
                    "memoryUsagePercent": metrics.memoryUsage,
                    "activeJobs": 0,
                    "queuedJobs": await jobRegistry.listJobs().count,
                    "isHealthy": true
                ]
                return HTTPResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONSerialization.data(withJSONObject: statusResponse)
                )
            } else {
                // Current format
                let metrics = await monitor.getMetrics()
                let status = DaemonStatus(
                    isRunning: isRunning,
                    metrics: metrics,
                    timestamp: Date()
                )
                return HTTPResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(status)
                )
            }
            
        case "/health":
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONEncoder().encode(["status": "healthy"])
            )
            
        case "/metrics":
            let metrics = await monitor.getMetrics()
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONEncoder().encode(metrics)
            )

        case "/jobs":
            switch request.method.uppercased() {
            case "GET":
                let jobs = await jobRegistry.listJobs()
                return HTTPResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(jobs)
                )
            case "POST":
                guard let body = request.body,
                      let jobRequest = try? JSONDecoder().decode(DaemonJobRequest.self, from: body) else {
                    return HTTPResponse(
                        statusCode: 400,
                        headers: ["Content-Type": "application/json"],
                        body: try? JSONEncoder().encode(["error": "Invalid job payload"])
                    )
                }
                let job = await jobRegistry.createJob(from: jobRequest)
                return HTTPResponse(
                    statusCode: 202,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(job)
                )
             default:
                return HTTPResponse(
                    statusCode: 405,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(["error": "Method not allowed"])
                )
            }
            
        case "/job/submit":
            guard request.method.uppercased() == "POST",
                  let body = request.body else {
                return HTTPResponse(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(["error": "Invalid request"])
                )
            }
            
            // Parse the SidecarBridge job submission
            // For now, create a simple job from the request
            let jobId = UUID().uuidString
            let jobResponse: [String: String] = [
                "jobId": jobId,
                "status": "QUEUED",
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            return HTTPResponse(
                statusCode: 202,
                headers: ["Content-Type": "application/json"],
                body: try? JSONEncoder().encode(jobResponse)
            )
            
        case "/job/status":
            // Extract job ID from query parameters
            let components = request.path.split(separator: "?")
            let jobId = components.count > 1 ? String(components[1]) : ""
            
            let statusResponse: [String: Any] = [
                "jobId": jobId,
                "status": "RUNNING",
                "progress": 0.5,
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "updatedAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONSerialization.data(withJSONObject: statusResponse)
            )
            
        case "/job/cancel":
            guard request.method.uppercased() == "POST",
                  let body = request.body else {
                return HTTPResponse(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(["error": "Invalid request"])
                )
            }
            
            let cancelResponse: [String: Any] = [
                "success": true,
                "message": "Job cancellation requested"
            ]
            
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONSerialization.data(withJSONObject: cancelResponse)
            )
            
        case "/artifacts/list":
            guard request.method.uppercased() == "POST" else {
                return HTTPResponse(
                    statusCode: 405,
                    headers: ["Content-Type": "application/json"],
                    body: try? JSONEncoder().encode(["error": "Method not allowed"])
                )
            }
            
            let artifactsResponse: [String: Any] = [
                "artifacts": [] as [String],
                "nextPageToken": ""
            ]
            
            return HTTPResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: try? JSONSerialization.data(withJSONObject: artifactsResponse)
            )
            
        default:
            return HTTPResponse(
                statusCode: 404,
                headers: ["Content-Type": "text/plain"],
                body: "Not Found".data(using: .utf8)
            )
        }
    }
}

// MARK: - HTTP Types

struct DaemonJobRequest: Codable {
    let action: String
    let repoPath: String
    let filePath: String
    let instruction: String
}

struct DaemonJob: Codable {
    let id: String
    let action: String
    let status: String
    let createdAt: Date
    let detail: String?
}

actor JobRegistry {
    private var jobs: [DaemonJob] = []

    func createJob(from request: DaemonJobRequest) -> DaemonJob {
        let job = DaemonJob(
            id: UUID().uuidString,
            action: request.action,
            status: "QUEUED",
            createdAt: Date(),
            detail: "\(request.filePath) • \(request.instruction)"
        )
        jobs.insert(job, at: 0)
        return job
    }

    func listJobs() -> [DaemonJob] {
        jobs
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?
}

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?
}

struct DaemonStatus: Codable {
    let isRunning: Bool
    let metrics: SystemMonitor.SystemMetrics
    let timestamp: Date
}

// MARK: - Async Socket Implementation

final class AsyncSocketListener: @unchecked Sendable {
    private let socket: Int32
    private let port: Int
    
    init(port: Int) async throws {
        self.port = port
        self.socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        guard socket >= 0 else {
            throw SocketError.failedToCreate
        }
        
        var reuseAddr: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(UInt16(port))
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult >= 0 else {
            Darwin.close(socket)
            throw SocketError.failedToBind
        }
        
        guard listen(socket, SOMAXCONN) >= 0 else {
            Darwin.close(socket)
            throw SocketError.failedToListen
        }
    }
    
    deinit {
        Darwin.close(socket)
    }
    
    var sockets: AsyncStream<AsyncSocket> {
        AsyncStream { continuation in
            Task {
                while true {
                    do {
                        let clientSocket = try await acceptConnection()
                        continuation.yield(clientSocket)
                    } catch {
                        continuation.finish()
                        break
                    }
                }
            }
        }
    }
    
    private func acceptConnection() async throws -> AsyncSocket {
        return try await withUnsafeThrowingContinuation { continuation in
            var addr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            
            DispatchQueue.global().async {
                let clientSocket = accept(self.socket, &addr, &addrLen)
                if clientSocket >= 0 {
                    continuation.resume(returning: AsyncSocket(socket: clientSocket))
                } else {
                    continuation.resume(throwing: SocketError.failedToAccept)
                }
            }
        }
    }
}

final class AsyncSocket: @unchecked Sendable {
    private let socket: Int32
    
    init(socket: Int32) {
        self.socket = socket
    }
    
    deinit {
        Darwin.close(socket)
    }
    
    func readRequest() async throws -> HTTPRequest {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var requestData = Data()
        let headerDelimiter = Data([13, 10, 13, 10])
        var headerEndIndex: Int?
        var contentLength = 0
        
        while true {
            let bytesRead = try await withUnsafeThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let result = read(self.socket, &buffer, buffer.count)
                    continuation.resume(returning: result)
                }
            }
            
            guard bytesRead > 0 else {
                throw SocketError.connectionClosed
            }
            
            requestData.append(buffer, count: bytesRead)

            if headerEndIndex == nil, let range = requestData.range(of: headerDelimiter) {
                headerEndIndex = range.upperBound
                let headerData = requestData[..<range.upperBound]
                if let headerString = String(data: headerData, encoding: .utf8) {
                    for line in headerString.components(separatedBy: "\r\n") {
                        if line.lowercased().hasPrefix("content-length:") {
                            let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                            contentLength = Int(value ?? "0") ?? 0
                        }
                    }
                }
                if contentLength == 0 {
                    return try parseHTTPRequest(requestData)
                }
            }

            if let headerEndIndex, contentLength > 0 {
                let bodyLength = requestData.count - headerEndIndex
                if bodyLength >= contentLength {
                    return try parseHTTPRequest(requestData)
                }
            }
        }
    }
    
    func writeResponse(_ response: HTTPResponse) async throws {
        var responseString = "HTTP/1.1 \(response.statusCode) \(statusMessage(for: response.statusCode))\r\n"
        
        for (key, value) in response.headers {
            responseString += "\(key): \(value)\r\n"
        }
        
        responseString += "\r\n"
        
        try await writeData(responseString.data(using: .utf8)!)
        
        if let body = response.body {
            try await writeData(body)
        }
    }
    
    func close() async throws {
        _ = Darwin.close(socket)
    }
    
    private func writeData(_ data: Data) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let result = data.withUnsafeBytes { buffer in
                    write(self.socket, buffer.baseAddress, data.count)
                }
                
                if result >= 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SocketError.failedToWrite)
                }
            }
        }
    }
    
    private func parseHTTPRequest(_ data: Data) throws -> HTTPRequest {
        guard let requestString = String(data: data, encoding: .utf8) else {
            throw SocketError.invalidRequest
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            throw SocketError.invalidRequest
        }
        
        let firstLineParts = firstLine.components(separatedBy: " ")
        guard firstLineParts.count >= 2 else {
            throw SocketError.invalidRequest
        }
        
        let method = firstLineParts[0]
        let path = firstLineParts[1]
        
        var headers: [String: String] = [:]
        var bodyStartIndex = 0
        
        for (index, line) in lines.enumerated() {
            if line.isEmpty && index < lines.count - 1 {
                bodyStartIndex = index + 1
                break
            }
            
            let headerParts = line.components(separatedBy: ": ")
            if headerParts.count == 2 {
                headers[headerParts[0]] = headerParts[1]
            }
        }
        
        let body: Data?
        if bodyStartIndex > 0 && bodyStartIndex < lines.count {
            let bodyLines = lines[bodyStartIndex...].joined(separator: "\r\n")
            body = bodyLines.data(using: .utf8)
        } else {
            body = nil
        }
        
        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: body
        )
    }
    
    private func statusMessage(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 405: return "Method Not Allowed"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

enum SocketError: Error {
    case failedToCreate
    case failedToBind
    case failedToListen
    case failedToAccept
    case connectionClosed
    case failedToWrite
    case invalidRequest
}

// MARK: - Configuration System

struct DaemonConfig: Codable {
    var serverPort: Int
    var logLevel: LogLevel
    var autoStart: Bool
    var enableNotifications: Bool
    var maxLogFiles: Int
    var maxLogSizeMB: Int
    var apiKey: String?
    var requireAuth: Bool
    
    static var `default`: DaemonConfig {
        DaemonConfig(
            serverPort: 8080,
            logLevel: .info,
            autoStart: true,
            enableNotifications: true,
            maxLogFiles: 5,
            maxLogSizeMB: 10,
            apiKey: nil,
            requireAuth: false
        )
    }
    
    static func load() -> DaemonConfig {
        let configURL = getConfigURL()
        
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(DaemonConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error)")
            return .default
        }
    }
    
    func save() throws {
        let configURL = DaemonConfig.getConfigURL()
        let data = try JSONEncoder().encode(self)
        try data.write(to: configURL)
    }
    
    private static func getConfigURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("AnigmaDaemon")
        
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        return appFolder.appendingPathComponent("config.json")
    }
}

enum LogLevel: String, Codable, CaseIterable {
    case debug, info, warning, error
}

// MARK: - Authentication Middleware

struct AuthMiddleware {
    private let config: DaemonConfig
    
    init(config: DaemonConfig) {
        self.config = config
    }
    
    func authenticate(request: HTTPRequest) -> Bool {
        // Skip auth for health check and session opening
        if request.path == "/health" || request.path == "/session/open" {
            return true
        }
        
        // If auth is not required, allow all requests
        guard config.requireAuth else {
            return true
        }
        
        // Check for API key in headers
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            // Check X-API-Key header
            if let apiKeyHeader = request.headers["X-API-Key"], apiKeyHeader == apiKey {
                return true
            }
            
            // Check Authorization: Bearer header
            if let authHeader = request.headers["Authorization"],
               authHeader.hasPrefix("Bearer ") {
                let token = String(authHeader.dropFirst("Bearer ".count))
                if token == apiKey {
                    return true
                }
            }
        }
        
        return false
    }
    
    func unauthorizedResponse() -> HTTPResponse {
        HTTPResponse(
            statusCode: 401,
            headers: ["Content-Type": "application/json"],
            body: try? JSONEncoder().encode(["error": "Unauthorized", "message": "Valid API key required"])
        )
    }
}

// MARK: - Enhanced Logging

actor Logger {
    private let config: DaemonConfig
    private var logFileHandle: FileHandle?
    private var currentLogSize: Int = 0
    private let logQueue = DispatchQueue(label: "com.anigma.daemon.logger")
    
    init(config: DaemonConfig) {
        self.config = config
        Task {
            await setupLogging()
        }
    }
    
    private func setupLogging() {
        let logURL = getLogURL()
        let logDir = logURL.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: logDir.path) {
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        }
        
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        
        do {
            logFileHandle = try FileHandle(forWritingTo: logURL)
            try logFileHandle?.seekToEnd()
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
               let size = attributes[.size] as? Int {
                currentLogSize = size
            }
        } catch {
            print("Failed to open log file: \(error)")
        }
        
        rotateLogsIfNeeded()
    }
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line) async {
        guard level.rawValue >= config.logLevel.rawValue else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"
        
        print(logMessage, terminator: "")
        
        // Capture file handle before entering closure
        let fileHandle = logFileHandle
        
        await withCheckedContinuation { continuation in
            logQueue.async {
                if let data = logMessage.data(using: .utf8) {
                    // Write to log file
                    try? fileHandle?.write(contentsOf: data)
                    
                    // Update log size on actor
                    Task { @MainActor in
                        await self.updateLogSize(data.count)
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func updateLogSize(_ bytes: Int) async {
        currentLogSize += bytes
        
        if currentLogSize > config.maxLogSizeMB * 1024 * 1024 {
            await rotateLog()
        }
    }
    
    private func rotateLogsIfNeeded() {
        let logDir = getLogURL().deletingLastPathComponent()
        
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.lastPathComponent.hasPrefix("anigmad") && $0.pathExtension == "log" }
                .sorted { ($0.lastPathComponent < $1.lastPathComponent) }
            
            if logFiles.count > config.maxLogFiles {
                let filesToDelete = logFiles.prefix(logFiles.count - config.maxLogFiles)
                for file in filesToDelete {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to rotate logs: \(error)")
        }
    }
    
    private func rotateLog() async {
        guard let currentHandle = logFileHandle else { return }
        
        do {
            try currentHandle.close()
            
            let currentLogURL = getLogURL()
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            
            let rotatedLogURL = currentLogURL.deletingLastPathComponent()
                .appendingPathComponent("anigmad-\(timestamp).log")
            
            try FileManager.default.moveItem(at: currentLogURL, to: rotatedLogURL)
            
            FileManager.default.createFile(atPath: currentLogURL.path, contents: nil)
            logFileHandle = try FileHandle(forWritingTo: currentLogURL)
            currentLogSize = 0
            
            rotateLogsIfNeeded()
        } catch {
            print("Failed to rotate log: \(error)")
        }
    }
    
    private func getLogURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("AnigmaDaemon")
        return appFolder.appendingPathComponent("anigmad.log")
    }
}

// MARK: - AI Service Integration

actor AIServiceManager {
    private let logger: Logger
    private var services: [AIService] = []
    private var healthCheckTask: Task<Void, Never>?
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func start() async {
        await logger.log(.info, "Starting AI service manager")
        
        healthCheckTask = Task {
            await runHealthChecks()
        }
    }
    
    func stop() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        await logger.log(.info, "Stopped AI service manager")
    }
    
    func registerService(_ service: AIService) {
        services.append(service)
        Task {
            await logger.log(.info, "Registered AI service: \(service.name)")
        }
    }
    
    func getServiceStatus() async -> [String: AIServiceStatus] {
        var status: [String: AIServiceStatus] = [:]
        
        for service in services {
            status[service.name] = await service.status
        }
        
        return status
    }
    
    private func runHealthChecks() async {
        while !Task.isCancelled {
            for service in services {
                await service.checkHealth()
            }
            
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }
}

protocol AIService: AnyObject, Sendable {
    var name: String { get }
    var status: AIServiceStatus { get async }
    func checkHealth() async
}

struct AIServiceStatus: Sendable {
    let isHealthy: Bool
    let lastCheck: Date
    let error: String?
    let latency: TimeInterval?
}

// MARK: - Daemon Manager

@MainActor
final class DaemonManager: ObservableObject {
    @Published var isRunning = false
    @Published var metrics = SystemMonitor.SystemMetrics(
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        diskIO: SystemMonitor.DiskIOMetrics(readBytes: 0, writeBytes: 0, readOps: 0, writeOps: 0),
        networkConnections: 0,
        uptime: 0.0
    )
    @Published var config = DaemonConfig.default
    @Published var aiServiceStatus: [String: AIServiceStatus] = [:]
    
    private let monitor = SystemMonitor()
    private let jobRegistry = JobRegistry()
    private var server: DaemonServer?
    private var logger: Logger?
    private var aiManager: AIServiceManager?
    private var metricsTask: Task<Void, Never>?
    
    init() {
        loadConfig()
    }
    
    func start() async {
        guard !isRunning else { return }
        
        isRunning = true
        
        logger = Logger(config: config)
        await logger?.log(.info, "Starting Anigma Daemon")
        
        server = DaemonServer(port: config.serverPort, monitor: monitor, jobRegistry: jobRegistry, config: config)
        await server?.start()
        
        aiManager = AIServiceManager(logger: logger!)
        await aiManager?.start()
        
        startMetricsCollection()
        
        await logger?.log(.info, "Anigma Daemon started successfully")
        
        if config.enableNotifications {
            showNotification(title: "Anigma Daemon", message: "Daemon started successfully")
        }
    }
    
    func stop() async {
        guard isRunning else { return }
        
        metricsTask?.cancel()
        metricsTask = nil
        
        await aiManager?.stop()
        await server?.stop()
        
        await logger?.log(.info, "Stopping Anigma Daemon")
        isRunning = false
        
        if config.enableNotifications {
            showNotification(title: "Anigma Daemon", message: "Daemon stopped")
        }
    }
    
    func restart() async {
        await stop()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await start()
    }
    
    func updateConfig(_ newConfig: DaemonConfig) async throws {
        config = newConfig
        try config.save()
        
        await logger?.log(.info, "Configuration updated")
        
        if isRunning {
            await restart()
        }
    }
    
    private func loadConfig() {
        config = DaemonConfig.load()
    }
    
    private func startMetricsCollection() {
        metricsTask = Task {
            while !Task.isCancelled {
                metrics = await monitor.getMetrics()
                
                if let aiManager = aiManager {
                    aiServiceStatus = await aiManager.getServiceStatus()
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                
                center.add(request)
            }
        }
    }
}

// MARK: - Menu Bar App

@main
struct AnigmaDaemonApp: App {
    @StateObject private var daemonManager = DaemonManager()
    @State private var showingConfig = false
    
    var body: some Scene {
        MenuBarExtra("Anigma Daemon", systemImage: daemonManager.isRunning ? "server.rack.fill" : "server.rack") {
            VStack(spacing: 12) {
                // Header
                VStack(spacing: 4) {
                    Text("Anigma Daemon")
                        .font(.headline)
                    Text(daemonManager.isRunning ? "Status: Running" : "Status: Stopped")
                        .font(.caption)
                        .foregroundColor(daemonManager.isRunning ? .green : .red)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Metrics Display
                if daemonManager.isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        MetricRow(label: "CPU:", value: "\(String(format: "%.1f", daemonManager.metrics.cpuUsage))%")
                        MetricRow(label: "Memory:", value: "\(String(format: "%.1f", daemonManager.metrics.memoryUsage))%")
                        MetricRow(label: "Uptime:", value: formatUptime(daemonManager.metrics.uptime))
                        MetricRow(label: "Connections:", value: "\(daemonManager.metrics.networkConnections)")
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // AI Services Status
                if !daemonManager.aiServiceStatus.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Services")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(daemonManager.aiServiceStatus.keys.sorted()), id: \.self) { serviceName in
                            if let status = daemonManager.aiServiceStatus[serviceName] {
                                HStack {
                                    Circle()
                                        .fill(status.isHealthy ? .green : .red)
                                        .frame(width: 6, height: 6)
                                    Text(serviceName)
                                        .font(.caption)
                                    Spacer()
                                    Text(status.isHealthy ? "✓" : "✗")
                                        .font(.caption)
                                        .foregroundColor(status.isHealthy ? .green : .red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // Control Buttons
                VStack(spacing: 8) {
                    if daemonManager.isRunning {
                        Button("Stop Daemon") {
                            Task {
                                await daemonManager.stop()
                            }
                        }
                        
                        Button("Restart Daemon") {
                            Task {
                                await daemonManager.restart()
                            }
                        }
                    } else {
                        Button("Start Daemon") {
                            Task {
                                await daemonManager.start()
                            }
                        }
                    }
                    
                    Button("Configuration") {
                        showingConfig = true
                    }
                    
                    Divider()
                    
                    Button("Open Logs") {
                        openLogs()
                    }
                    
                    Button("Diagnostics") {
                        showDiagnostics()
                    }
                    
                    Divider()
                    
                    Button("Quit") {
                        Task {
                            await daemonManager.stop()
                        }
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .frame(width: 280)
        }
        .menuBarExtraStyle(.window)
        
        // Configuration Window
        Window("Daemon Configuration", id: "config") {
            ConfigView(daemonManager: daemonManager, isPresented: $showingConfig)
        }
        .defaultSize(width: 400, height: 500)
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func openLogs() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logFolder = appSupport.appendingPathComponent("AnigmaDaemon")
        
        if FileManager.default.fileExists(atPath: logFolder.path) {
            NSWorkspace.shared.open(logFolder)
        }
    }
    
    private func showDiagnostics() {
        let alert = NSAlert()
        alert.messageText = "Daemon Diagnostics"
        alert.informativeText = """
        Server Port: \(daemonManager.config.serverPort)
        Log Level: \(daemonManager.config.logLevel.rawValue)
        Auto Start: \(daemonManager.config.autoStart ? "Yes" : "No")
        Notifications: \(daemonManager.config.enableNotifications ? "Enabled" : "Disabled")
        
        Current Metrics:
        CPU: \(String(format: "%.1f", daemonManager.metrics.cpuUsage))%
        Memory: \(String(format: "%.1f", daemonManager.metrics.memoryUsage))%
        Uptime: \(formatUptime(daemonManager.metrics.uptime))
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
        }
    }
}

struct ConfigView: View {
    @ObservedObject var daemonManager: DaemonManager
    @Binding var isPresented: Bool
    
    @State private var localConfig: DaemonConfig
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
    init(daemonManager: DaemonManager, isPresented: Binding<Bool>) {
        self.daemonManager = daemonManager
        self._isPresented = isPresented
        self._localConfig = State(initialValue: daemonManager.config)
    }
    
    var body: some View {
        Form {
            Section("Server Configuration") {
                HStack {
                    Text("Port:")
                    TextField("Port", value: $localConfig.serverPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                Toggle("Auto Start on Login", isOn: $localConfig.autoStart)
                Toggle("Enable Notifications", isOn: $localConfig.enableNotifications)
            }
            
            Section("Logging Configuration") {
                Picker("Log Level", selection: $localConfig.logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                
                HStack {
                    Text("Max Log Size:")
                    TextField("MB", value: $localConfig.maxLogSizeMB, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("MB")
                }
                
                HStack {
                    Text("Max Log Files:")
                    TextField("Files", value: $localConfig.maxLogFiles, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
            }
            
            Section {
                HStack {
                    Button("Save") {
                        saveConfig()
                    }
                    .keyboardShortcut(.defaultAction)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
        .alert("Configuration Saved", isPresented: $showingSaveAlert) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text(saveMessage)
        }
    }
    
    private func saveConfig() {
        Task {
            do {
                try await daemonManager.updateConfig(localConfig)
                saveMessage = "Configuration saved successfully. Daemon will restart if running."
                showingSaveAlert = true
            } catch {
                saveMessage = "Failed to save configuration: \(error.localizedDescription)"
                showingSaveAlert = true
            }
        }
    }
}
