import Foundation

// MARK: - ProjectConfigurationLoader
public actor ProjectConfigurationLoader {
    private let configFolder = ".anigma"

    public func detectLocalConfiguration(at path: URL) async -> LocalConfig? {
        // Implementation for scanning .anigma/ folder for TUI themes and custom commands
        return nil
    }
}

public struct LocalConfig: Sendable {
    let customThemes: [String: Theme]
    let customCommands: [String: String]
}
