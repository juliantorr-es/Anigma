//
//  DaemonServer+PTY.swift
//  AnigmaDaemonCore
//
//  Handlers for Persistent Shell Sessions.
//

import Foundation
import AnigmaPrimitives

extension DaemonServer {
    
    // MARK: - Handlers
    
    func handleCreateSession(request: CreateSessionRequest) async throws -> SessionInfo {
        let session = try await sessionManager.createSession(
            command: request.command ?? "/bin/bash",
            args: request.args ?? [],
            workdir: request.workdir ?? FileManager.default.currentDirectoryPath,
            env: request.env ?? [:]
        )
        return await session.getInfo()
    }
    
    func handleWriteSession(id: String, input: String) async throws -> Bool {
        guard let session = await sessionManager.getSession(id) else {
            throw DaemonError.sessionNotFound(id)
        }
        await session.write(input)
        return true
    }
    
    func handleReadSession(id: String, offset: Int64) async throws -> ReadSessionResponse {
        guard let session = await sessionManager.getSession(id) else {
            throw DaemonError.sessionNotFound(id)
        }
        
        let buffer = session.buffer
        let data = await buffer.read(from: offset)
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Calculate next offset
        // In a real system, we'd want to return the absolute offset of the buffer head
        let bytesRead = Int64(data.count)
        let nextOffset = offset + bytesRead
        
        return ReadSessionResponse(
            sessionId: id,
            output: output,
            nextOffset: nextOffset
        )
    }
    
    func handleListSessions() async -> [SessionInfo] {
        return await sessionManager.listSessions()
    }
    
    func handleKillSession(id: String) async -> Bool {
        await sessionManager.killSession(id)
        return true
    }
}

// MARK: - DTOs

public struct CreateSessionRequest: Codable, Sendable {
    public let command: String?
    public let args: [String]?
    public let workdir: String?
    public let env: [String: String]?
}

public struct ReadSessionResponse: Codable, Sendable {
    public let sessionId: String
    public let output: String
    public let nextOffset: Int64
}

public struct WriteSessionRequest: Codable, Sendable {
    public let input: String
}

public struct ReadSessionRequest: Codable, Sendable {
    public let offset: Int64?
}

// Errors
enum DaemonError: Error {
    case alreadyRunning
    case sessionNotFound(String)
    case rateLimitExceeded
    case configurationError(String)
    case invalidPageToken(String)
}
