import Foundation

public enum DaemonHostStatus: String, Codable, Sendable {
    case online, offline, connecting, error
}

public struct DaemonHost: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let status: DaemonHostStatus

    public init(id: String, name: String, url: URL, status: DaemonHostStatus) {
        self.id = id
        self.name = name
        self.url = url
        self.status = status
    }
}
