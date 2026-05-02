//
//  ConflictManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public struct Conflict: Codable, Identifiable, Sendable {
    public let id: UUID
    public let objectId: String
    public let objectType: String
    public let sourceSystem: String
    public let detectedAt: Date
    public let description: String
    public let status: ConflictStatus
    public let resolution: String?

    public init(
        id: UUID = UUID(),
        objectId: String,
        objectType: String,
        sourceSystem: String,
        detectedAt: Date = Date(),
        description: String,
        status: ConflictStatus = .open,
        resolution: String? = nil
    ) {
        self.id = id
        self.objectId = objectId
        self.objectType = objectType
        self.sourceSystem = sourceSystem
        self.detectedAt = detectedAt
        self.description = description
        self.status = status
        self.resolution = resolution
    }
}

public actor ConflictManager {
    private var conflicts: [String: [Conflict]] = [:] // SpaceID -> Conflicts

    public init() {}

    public func reportConflict(spaceId: String, conflict: Conflict) {
        var spaceConflicts = conflicts[spaceId] ?? []
        spaceConflicts.append(conflict)
        conflicts[spaceId] = spaceConflicts
    }

    public func getConflicts(spaceId: String) -> [Conflict] {
        return conflicts[spaceId] ?? []
    }

    public func resolveConflict(spaceId: String, conflictId: UUID, resolution: String) {
        guard var spaceConflicts = conflicts[spaceId] else { return }

        if let index = spaceConflicts.firstIndex(where: { $0.id == conflictId }) {
            let oldConflict = spaceConflicts[index]
            let resolvedConflict = Conflict(
                id: oldConflict.id,
                objectId: oldConflict.objectId,
                objectType: oldConflict.objectType,
                sourceSystem: oldConflict.sourceSystem,
                detectedAt: oldConflict.detectedAt,
                description: oldConflict.description,
                status: .resolved,
                resolution: resolution
            )
            spaceConflicts[index] = resolvedConflict
            conflicts[spaceId] = spaceConflicts
        }
    }

    public func attemptAutoResolution(spaceId: String, conflictId: UUID) -> Bool {
        // Stub for auto-resolution logic
        // In a real implementation, this would check rules based on objectType and field
        return false
    }
}
