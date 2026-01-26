import Foundation

public final class FixtureManager: @unchecked Sendable {
    public static let shared = FixtureManager()
    
    private init() {}

    public func findProjectRoot() -> String {
        let fileManager = FileManager.default
        var currentPath = fileManager.currentDirectoryPath
        // Look for root Package.swift
        while currentPath != "/" {
            let packageSwiftPath = "\(currentPath)/Package.swift"
            if fileManager.fileExists(atPath: packageSwiftPath) {
                // Check if it's the root one (it's very large)
                if let attr = try? fileManager.attributesOfItem(atPath: packageSwiftPath),
                   let size = attr[.size] as? UInt64, size > 10000 {
                    return currentPath
                }
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        return "/Users/user/Developer/GitHub/Anigma_clean/anigma"
    }

    public func load(_ relativePath: String) throws -> Data {
        // relativePath format: "PackageName/filename.golden"
        // Target location: Packages/PackageName/Tests/Golden/filename.golden
        
        let root = findProjectRoot()
        let components = relativePath.split(separator: "/")
        
        guard components.count >= 2 else {
            throw NSError(domain: "FixtureManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid golden path format. Expected 'PackageName/filename.golden', got '\(relativePath)'"])
        }
        
        let packageName = components[0]
        let fileName = components[1...].joined(separator: "/")
        
        let fullPath = "\(root)/Packages/\(packageName)/Tests/Golden/\(fileName)"
        let url = URL(fileURLWithPath: fullPath)
        
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw NSError(domain: "FixtureManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Golden file not found at \(fullPath)"])
        }
        
        return try Data(contentsOf: url)
    }
    
    public func saveUpdatedGolden(actual: Data, relativePath: String) throws {
        let root = findProjectRoot()
        let components = relativePath.split(separator: "/")
        guard components.count >= 2 else { return }
        
        let packageName = components[0]
        let fileName = components[1...].joined(separator: "/")
        
        let fullPath = "\(root)/Packages/\(packageName)/Tests/Golden/\(fileName)"
        try actual.write(to: URL(fileURLWithPath: fullPath))
    }
}
