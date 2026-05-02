//
//  JobRegistry.swift
//  AnigmaDaemonCore
//
//  Component for registering and retrieving job handlers.
//

import AnigmaPrimitives
import Foundation

/// A registry for job handlers to decouple DaemonServer from specific job implementations.
public actor JobRegistry {
    private var workers: [String: JobWorker] = [:]

    public init() {}

    /// Register a worker for a specific job kind.
    public func register(worker: JobWorker) {
        workers[type(of: worker).kind] = worker
    }

    /// Retrieve a worker for a given job kind.
    public func worker(for kind: String) -> JobWorker? {
        return workers[kind]
    }

    /// List all supported job kinds.
    public func registeredKinds() -> [String] {
        return Array(workers.keys).sorted()
    }
}
