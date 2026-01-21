//
//  DiaplasionFixtures.swift
//  DiaplasionModule
//
//  [Brief description of file purpose]
//

import Foundation

private class CurrentBundleFinder {}

public enum DiaplasionModuleResources {
    public static func urlForHappyPathSpec() throws -> URL {
        try baseResourceURL().appendingPathComponent("diaplasion-happy/spec.json")
    }

    public static func baseURLForHappyPathFixtures() throws -> URL {
        try baseResourceURL().appendingPathComponent("diaplasion-happy")
    }

    private static func baseResourceURL() throws -> URL {
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
                return "Bundle resources directory is missing"
            }
        }
    }
}
