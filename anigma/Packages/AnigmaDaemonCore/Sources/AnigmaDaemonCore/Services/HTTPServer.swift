import Foundation
import Darwin
import OSLog

internal let httpTransportLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "HTTPTransport")

/// Manages the lifecycle of the daemon's internal HTTP transport.
internal actor HTTPServerManager {
    private var listener: UnixHTTPListener?
    private var acceptTask: Task<Void, Never>?
    private var socketPath: String?

    func start(configuration: DaemonConfiguration.DaemonConfig, daemon: DaemonServer) async throws {
        let path = (configuration.unixSocket as NSString).expandingTildeInPath
        self.socketPath = path
        httpTransportLogger.info("Starting daemon HTTP transport on unix socket '\(path, privacy: .public)'")

        // Alignment: Explicit socket ownership and binding
        let listener = try UnixHTTPListener(socketPath: path)
        self.listener = listener

        acceptTask = Task {
            for await connection in listener.connections {
                Task {
                    do {
                        let request = try await connection.readRequest()
                        httpTransportLogger.debug("Accepted HTTP request \(request.method, privacy: .public) \(request.path, privacy: .public)")
                        let response = await daemon.handleHTTPRequest(request)
                        try await connection.writeResponse(response)
                        try await connection.close()
                    } catch {
                        httpTransportLogger.error("HTTP connection failed: \(error.localizedDescription, privacy: .public)")
                        try? await connection.close()
                    }
                }
            }
        }
    }

    func stop() async {
        httpTransportLogger.info("Stopping daemon HTTP transport")
        acceptTask?.cancel()
        acceptTask = nil
        listener = nil

        if let socketPath {
            // Alignment: Cleanup of bound socket file
            try? FileManager.default.removeItem(atPath: socketPath)
            self.socketPath = nil
        }
    }
}

internal struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?
}

internal struct HTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?
}

internal enum HTTPServerError: LocalizedError {
    case failedToCreateSocket
    case failedToBindSocket(path: String, errno: Int32)
    case failedToListen(errno: Int32)
    case failedToAccept
    case invalidRequest
    case connectionClosed
    case failedToWrite

    var errorDescription: String? {
        switch self {
        case .failedToCreateSocket: return "Failed to create unix domain socket"
        case .failedToBindSocket(let path, let code): return "Failed to bind to socket '\(path)' (errno: \(code))"
        case .failedToListen(let code): return "Failed to listen on socket (errno: \(code))"
        case .failedToAccept: return "Failed to accept connection"
        case .invalidRequest: return "Invalid HTTP request"
        case .connectionClosed: return "Connection closed"
        case .failedToWrite: return "Failed to write to socket"
        }
    }
}

/// Low-level Unix Domain Socket listener for HTTP.
internal final class UnixHTTPListener: @unchecked Sendable {
    private let socket: Int32
    private let socketPath: String

    init(socketPath: String) throws {
        self.socketPath = socketPath
        self.socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

        guard socket >= 0 else {
            throw HTTPServerError.failedToCreateSocket
        }

        // Alignment: Ensure parent directory exists and stale socket is removed
        let parent = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: socketPath)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        let pathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= pathCapacity else {
            Darwin.close(socket)
            throw HTTPServerError.failedToBindSocket(path: socketPath, errno: ENAMETOOLONG)
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            raw.initialize(repeating: 0, count: pathCapacity)
            pathBytes.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    raw.update(from: baseAddress, count: buffer.count)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult >= 0 else {
            let err = errno
            Darwin.close(socket)
            throw HTTPServerError.failedToBindSocket(path: socketPath, errno: err)
        }

        guard Darwin.listen(socket, SOMAXCONN) >= 0 else {
            let err = errno
            Darwin.close(socket)
            throw HTTPServerError.failedToListen(errno: err)
        }
    }

    deinit {
        Darwin.close(socket)
        // Alignment: Cleanup bound path on deinit
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    var connections: AsyncStream<UnixHTTPConnection> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    do {
                        continuation.yield(try await acceptConnection())
                    } catch {
                        continuation.finish()
                        break
                    }
                }
            }
        }
    }

    private func acceptConnection() async throws -> UnixHTTPConnection {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let clientSocket = Darwin.accept(self.socket, nil, nil)
                if clientSocket >= 0 {
                    httpTransportLogger.debug("Accepted unix socket client fd=\(clientSocket, privacy: .public)")
                    continuation.resume(returning: UnixHTTPConnection(socket: clientSocket))
                } else {
                    httpTransportLogger.error("Failed accepting unix socket client")
                    continuation.resume(throwing: HTTPServerError.failedToAccept)
                }
            }
        }
    }
}

internal final class UnixHTTPConnection: @unchecked Sendable {
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
            let bytesRead: Int = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let result = Darwin.read(self.socket, &buffer, buffer.count)
                    if result >= 0 {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: HTTPServerError.connectionClosed)
                    }
                }
            }

            guard bytesRead > 0 else {
                httpTransportLogger.error("Unix socket connection closed before complete request")
                throw HTTPServerError.connectionClosed
            }

            requestData.append(buffer, count: bytesRead)

            if headerEndIndex == nil, let range = requestData.range(of: headerDelimiter) {
                headerEndIndex = range.upperBound
                if let headerString = String(data: requestData[..<range.upperBound], encoding: .utf8) {
                    for line in headerString.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("content-length:") {
                        let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                        contentLength = Int(value ?? "0") ?? 0
                    }
                }
                if contentLength == 0 {
                    return try parseHTTPRequest(requestData)
                }
            }

            if let headerEndIndex, contentLength > 0, requestData.count - headerEndIndex >= contentLength {
                return try parseHTTPRequest(requestData)
            }
        }
    }

    func writeResponse(_ response: HTTPResponse) async throws {
        httpTransportLogger.debug("Writing HTTP response status=\(response.statusCode, privacy: .public)")
        var headers = response.headers
        headers["Content-Length"] = String(response.body?.count ?? 0)
        headers["Connection"] = "close"

        var responseString = "HTTP/1.1 \(response.statusCode) \(statusMessage(for: response.statusCode))\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        guard let headerData = responseString.data(using: .utf8) else {
            throw HTTPServerError.failedToWrite
        }
        try await writeData(headerData)
        if let body = response.body {
            try await writeData(body)
        }
    }

    func close() async throws {
        _ = Darwin.close(socket)
    }

    private func writeData(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let written = data.withUnsafeBytes { buffer in
                    Darwin.write(self.socket, buffer.baseAddress, data.count)
                }
                if written >= 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HTTPServerError.failedToWrite)
                }
            }
        }
    }

    private func parseHTTPRequest(_ data: Data) throws -> HTTPRequest {
        guard let requestString = String(data: data, encoding: .utf8) else {
            throw HTTPServerError.invalidRequest
        }

        let parts = requestString.components(separatedBy: "\r\n\r\n")
        let head = parts.first ?? ""
        let bodyString = parts.count > 1 ? parts[1] : ""
        let lines = head.components(separatedBy: "\r\n")

        guard let firstLine = lines.first else {
            throw HTTPServerError.invalidRequest
        }

        let firstLineParts = firstLine.components(separatedBy: " ")
        guard firstLineParts.count >= 2 else {
            throw HTTPServerError.invalidRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let headerParts = line.components(separatedBy: ": ")
            if headerParts.count == 2 {
                headers[headerParts[0]] = headerParts[1]
            }
        }

        return HTTPRequest(
            method: firstLineParts[0],
            path: firstLineParts[1],
            headers: headers,
            body: bodyString.isEmpty ? nil : Data(bodyString.utf8)
        )
    }

    private func statusMessage(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
