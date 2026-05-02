//
//  UIModels.swift
//  AnigmaAppMac
//
//  UI-specific state models and filters.
//

import Foundation
import AnigmaClientKit

/// Selection state for the side inspector panel
public enum InspectorSelection: Hashable, Sendable {
    case artifact(id: ArtifactID)
    case job(id: JobID)
    case receipt(hash: String)
    case entity(id: String)
}

/// Filter for job status in the activity list
public enum JobStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case running = "Running"
    case completed = "Completed"
    case failed = "Failed"
    
    public var id: String { rawValue }
}

/// Filter for job trust status
public enum JobTrustFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case trusted = "Trusted"
    case untrusted = "Untrusted"
    
    public var id: String { rawValue }
}

/// Project representation within a workspace
public struct WorkbenchProject: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let rootPath: String
    public var lastOpened: Date?
    
    public init(id: String = UUID().uuidString, name: String, rootPath: String, lastOpened: Date? = nil) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.lastOpened = lastOpened
    }
}
