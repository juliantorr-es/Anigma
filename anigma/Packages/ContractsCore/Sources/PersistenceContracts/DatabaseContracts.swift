import Foundation

public enum DatabaseParameter: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case date(Date)
    case null
}

public enum DatabaseValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case date(Date)
    case null

    public var stringValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }
}

public struct DatabaseRow: Sendable {
    public let values: [String: DatabaseValue]
    public init(values: [String: DatabaseValue]) { self.values = values }
}

public protocol DatabaseExecutor: Actor, Sendable {
    @discardableResult
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]
    
    @discardableResult
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    
    func transaction(_ block: @escaping @Sendable () async throws -> Void) async throws
    
    func open() throws
    
    func close()
    
    func isVectorAvailable() async -> Bool
    
    nonisolated var path: String { get }
}
