//
//  VaultLayout.swift
//  StorageCore
//
//  Deterministic filesystem layout for the vault.
//

import Foundation

/// Vault layout describing the filesystem paths for stored artifacts.
public struct VaultLayout: Sendable {
    public let rootURL: URL
    public let objectsURL: URL
    public let manifestsURL: URL
    public let quarantineURL: URL
    public let tempURL: URL
    public let ledgerURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
        self.objectsURL = rootURL.appendingPathComponent("objects", isDirectory: true)
        self.manifestsURL = rootURL.appendingPathComponent("manifests", isDirectory: true)
        self.quarantineURL = rootURL.appendingPathComponent("quarantine", isDirectory: true)
        self.tempURL = rootURL.appendingPathComponent("temp", isDirectory: true)
        self.ledgerURL = rootURL.appendingPathComponent("ledger", isDirectory: true)
    }

    /// Returns the on-disk path for a SHA-256 hex hash.
    public func objectURL(forSHA256Hex hash: String) throws -> URL {
        guard hash.count >= 4 else { throw VaultError.invalidHash }
        let prefix = String(hash.prefix(2))
        let next = String(hash.dropFirst(2).prefix(2))
        return objectsURL
            .appendingPathComponent("sha256", isDirectory: true)
            .appendingPathComponent(prefix, isDirectory: true)
            .appendingPathComponent(next, isDirectory: true)
            .appendingPathComponent(hash, isDirectory: false)
    }

    /// Returns the directory for a quarantined ticket.
    public func quarantineTicketURL(_ ticketId: String) -> URL {
        quarantineURL.appendingPathComponent(ticketId, isDirectory: true)
    }

    /// Returns the manifests directory for run artifacts.
    public func runManifestURL(_ runId: String) -> URL {
        manifestsURL
            .appendingPathComponent("runs", isDirectory: true)
            .appendingPathComponent("\(runId).json", isDirectory: false)
    }
}
