//
//  OutlineumFixtures.swift
//  OutlineumModule
//
//  Canonical fixture definitions for OutlineumModule.
//

import Foundation

private class CurrentBundleFinder {}

public enum OutlineumModuleResources {
    /// Canonical relative path to the default zine spec within the repository.
    public static let canonicalSpecRelativePath = "Packages/OutlineumModule/TestFiles/zine-minimal/spec.json"

    /// Returns the URL for the canonical zine-minimal spec.
    public static func urlForMinimalZineSpec() throws -> URL {
        try baseResourceURL().appendingPathComponent("TestFiles/zine-minimal/spec.json")
    }

    /// Returns the base URL for zine-minimal fixture assets.
    public static func baseURLForMinimalZineFixtures() throws -> URL {
        try baseResourceURL().appendingPathComponent("TestFiles/zine-minimal")
    }

    private static func baseResourceURL() throws -> URL {
        // Attempt to find resources relative to the current file path (development/test usage)
        let moduleRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: moduleRoot.path) {
            return moduleRoot
        }
        
        // Fallback to bundle resources if properly packaged
        let bundle = Bundle(for: CurrentBundleFinder.self)
        guard let resources = bundle.resourceURL else {
            throw ResourceError.missingResourceRoot
        }
        return resources
    }

    enum ResourceError: Error, LocalizedError {
        case missingResourceRoot

        var errorDescription: String? {
            switch self {
            case .missingResourceRoot:
                return "OutlineumModule resources directory is missing"
            }
        }
    }
}
