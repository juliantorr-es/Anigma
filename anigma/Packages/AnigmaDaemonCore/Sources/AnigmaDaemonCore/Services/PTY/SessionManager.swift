//
//  SessionManager.swift
//  AnigmaDaemonCore
//
//  Manages lifecycle of multiple ShellSessions.
//

import Foundation

public actor SessionManager {
    private var sessions: [String: ShellSession] = [:]
    
    public init() {}
    
    public func createSession(command: String, args: [String], workdir: String, env: [String: String]) async throws -> ShellSession {
        let id = UUID().uuidString
        let session = ShellSession(id: id, command: command, args: args, workdir: workdir, env: env)
        try await session.start()
        sessions[id] = session
        return session
    }
    
    public func getSession(_ id: String) -> ShellSession? {
        return sessions[id]
    }
    
    public func listSessions() async -> [SessionInfo] {
        var infos: [SessionInfo] = []
        for session in sessions.values {
            infos.append(await session.getInfo())
        }
        return infos
    }
    
    public func killSession(_ id: String) async {
        if let session = sessions[id] {
            await session.kill()
            sessions.removeValue(forKey: id)
        }
    }
    
    public func cleanupAll() async {
        for session in sessions.values {
            await session.kill()
        }
        sessions.removeAll()
    }
}
