//
//  AnigmaVirtualURI.swift
//  DevelopumModule
//
//  Virtual URI scheme for Anigma document references.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

/// Virtual URI scheme for Anigma document references.
/// Content is served via RPC, not URL fetching.
public enum AnigmaVirtualURI {
    /// Scheme identifier.
    public static let scheme = "anigma"

    /// Creates a virtual URI for a document.
    public static func documentURI(repoId: UUID, filePath: String) -> String {
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath
        return "\(scheme)://\(repoId.uuidString)/\(encodedPath)"
    }

    /// Extracts the repo ID from a virtual URI.
    public static func repoId(from uri: String) -> UUID? {
        guard uri.hasPrefix("\(scheme)://") else { return nil }
        let withoutScheme = String(uri.dropFirst("\(scheme)://".count))
        let components = withoutScheme.split(separator: "/", maxSplits: 1)
        guard components.count >= 1 else { return nil }
        return UUID(uuidString: String(components[0]))
    }

    /// Extracts the file path from a virtual URI.
    public static func filePath(from uri: String) -> String? {
        guard uri.hasPrefix("\(scheme)://") else { return nil }
        let withoutScheme = String(uri.dropFirst("\(scheme)://".count))
        let components = withoutScheme.split(separator: "/", maxSplits: 1)
        guard components.count >= 2 else { return nil }
        let path = String(components[1])
        return path.removingPercentEncoding ?? path
    }
}
