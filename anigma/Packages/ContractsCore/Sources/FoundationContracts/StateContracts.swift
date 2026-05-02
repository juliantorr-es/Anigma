import AnigmaPrimitives
import Foundation

/// Slice of state provided to step
public struct StateSlice: Sendable, Codable {
    public let entities: [StateEntity]
    public let relations: [StateRelation]
    public let metadata: [String: String]

    public init(entities: [StateEntity] = [], relations: [StateRelation] = [], metadata: [String: String] = [:]) {
        self.entities = entities
        self.relations = relations
        self.metadata = metadata
    }
}

/// Delta representing changes to state
public struct StateDelta: Sendable, Codable {
    public let addedEntities: [StateEntity]
    public let modifiedEntities: [StateEntity]
    public let deletedEntities: [String]  // Entity IDs
    public let addedRelations: [StateRelation]
    public let deletedRelations: [String]  // Relation IDs

    public init(addedEntities: [StateEntity] = [], modifiedEntities: [StateEntity] = [], deletedEntities: [String] = [], addedRelations: [StateRelation] = [], deletedRelations: [String] = []) {
        self.addedEntities = addedEntities
        self.modifiedEntities = modifiedEntities
        self.deletedEntities = deletedEntities
        self.addedRelations = addedRelations
        self.deletedRelations = deletedRelations
    }
}

/// Entity in state slice
public struct StateEntity: Sendable, Codable {
    public let id: String
    public let type: String
    public let attributes: [String: String]
    
    public init(id: String, type: String, attributes: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.attributes = attributes
    }
}

/// Relation in state slice
public struct StateRelation: Sendable, Codable {
    public let id: String
    public let type: String
    public let fromId: String
    public let toId: String
    public let attributes: [String: String]
    
    public init(id: String, type: String, fromId: String, toId: String, attributes: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.fromId = fromId
        self.toId = toId
        self.attributes = attributes
    }
}
