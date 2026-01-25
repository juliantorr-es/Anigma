//
//  TCPClient.swift
//  DevelopumModule
//
//  TCP client for LSP communication over network.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

public actor TCPClient {
    private let host: String
    private let port: Int
    private var socket: Int32 = -1
    private var isConnected: Bool = false
    private var receiveTask: Task<Void, Never>?

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        socket = Darwin.socket(Darwin.AF_INET, Darwin.SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw TCPClientError.socketCreationFailed
        }

        var hints = addrinfo()
        hints.ai_family = Darwin.AF_INET
        hints.ai_socktype = Darwin.SOCK_STREAM
        hints.ai_protocol = Darwin.IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &result) == 0, let addrList = result else {
            throw TCPClientError.dnsResolutionFailed
        }
        defer { freeaddrinfo(addrList) }

        let sockaddr = addrList.pointee
        guard Darwin.connect(socket, sockaddr.ai_addr, sockaddr.ai_addrlen) == 0 else {
            throw TCPClientError.connectionFailed
        }

        isConnected = true
        receiveTask = Task {
            await receiveLoop()
        }
    }

    public func disconnect() {
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        if socket >= 0 {
            Darwin.close(socket)
            socket = -1
        }
    }

    public func send(_ data: Data) async throws {
        guard isConnected, socket >= 0 else {
            throw TCPClientError.notConnected
        }

        var bytesSent = 0
        let totalBytes = data.count
        let buffer = [UInt8](data)

        while bytesSent < totalBytes {
            let result = buffer.withUnsafeBytes { ptr in
                Darwin.send(socket, ptr.baseAddress!.advanced(by: bytesSent), totalBytes - bytesSent, 0)
            }
            guard result > 0 else {
                throw TCPClientError.sendFailed
            }
            bytesSent += result
        }
    }

    public func read() async throws -> Data {
        guard isConnected, socket >= 0 else {
            throw TCPClientError.notConnected
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(socket, &buffer, 4096)

        guard bytesRead > 0 else {
            throw TCPClientError.readFailed
        }

        return Data(buffer[0..<bytesRead])
    }

    private func receiveLoop() async {
        while isConnected {
            do {
                _ = try await read()
            } catch {
                break
            }
        }
    }
}

public enum TCPClientError: Error, LocalizedError {
    case socketCreationFailed
    case dnsResolutionFailed
    case connectionFailed
    case notConnected
    case sendFailed
    case readFailed

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .dnsResolutionFailed:
            return "DNS resolution failed"
        case .connectionFailed:
            return "Connection failed"
        case .notConnected:
            return "Not connected"
        case .sendFailed:
            return "Send failed"
        case .readFailed:
            return "Read failed"
        }
    }
}
