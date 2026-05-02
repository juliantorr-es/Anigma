import Foundation
import AnigmaSystemSpine
import DataCore

public enum ExportInput: Sendable, Codable, Hashable {
    case file(url: URL)
    case artifact(id: String)
    case document(id: String)
    case dataset(id: String)
    case context(id: String)
    case project(id: String)
    case repoWorkspace(id: String)
}

public enum ExportTarget: Sendable, Codable, Hashable {
    case folder(url: URL)
    case zip(url: URL, encrypted: Bool)
    case bundle(url: URL)
    case connector(id: String, path: String)
}

public struct ExportOptions: Sendable, Codable, Hashable {
    public var label: String?
    public var namingPolicyId: String?
    public var includeReceipts: Bool = true
    public var includeManifest: Bool = true
    public var includeRawInputs: Bool = false
    public var redactionPolicyId: String?
    public var retentionPolicyId: String?

    public init() {}
}

public struct ExportRequest: Sendable, Codable {
    public var inputs: [ExportInput]
    public var profileId: String
    public var target: ExportTarget
    public var options: ExportOptions

    public init(inputs: [ExportInput], profileId: String, target: ExportTarget, options: ExportOptions = .init()) {
        self.inputs = inputs
        self.profileId = profileId
        self.target = target
        self.options = options
    }
}

public enum ExportEvent: Sendable {
    case started(jobId: String)
    case phase(name: String)
    case progress(completed: Int, total: Int?)
    case output(url: URL, role: String)
    case finished(success: Bool, receiptRef: String?)
    case failed(message: String, receiptRef: String?)
}
