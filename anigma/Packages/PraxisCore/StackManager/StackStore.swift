//
//  StackStore.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum StackStoreError: Error, CustomStringConvertible, Sendable {
    case notFound(String)
    case alreadyExists(String)
    case invalidID(String)

    public var description: String {
        switch self {
        case .notFound(let id): return "Stack not found: \(id)"
        case .alreadyExists(let id): return "Stack already exists: \(id)"
        case .invalidID(let id): return "Invalid stack id: \(id)"
        }
    }
}

public struct StackStore: Sendable {
    public let repoRoot: URL

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    public func stacksDir() -> URL {
        repoRoot.appendingPathComponent(".anigma", isDirectory: true)
            .appendingPathComponent("stacks", isDirectory: true)
    }

    public func stackURL(stackID: String) throws -> URL {
        let id = try normalizeID(stackID)
        return stacksDir().appendingPathComponent("\(id).json", isDirectory: false)
    }

    public func listStackIDs() throws -> [String] {
        let dir = stacksDir()
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let items = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        return items.compactMap { name in
            guard name.hasSuffix(".json") else { return nil }
            return String(name.dropLast(5))
        }.sorted()
    }

    public func load(stackID: String) throws -> StackRecord {
        let url = try stackURL(stackID: stackID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StackStoreError.notFound(stackID)
        }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(StackRecord.self, from: data)
    }

    public func save(_ record: StackRecord, overwrite: Bool = true) throws {
        try FileManager.default.createDirectory(at: stacksDir(), withIntermediateDirectories: true)
        let url = try stackURL(stackID: record.stackID)
        if !overwrite, FileManager.default.fileExists(atPath: url.path) {
            throw StackStoreError.alreadyExists(record.stackID)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(record)
        try data.write(to: url, options: [.atomic])
    }

    public func create(stackID: String, baseBranch: String, remote: String?, force: Bool) throws -> StackRecord {
        let id = try normalizeID(stackID)
        let url = try stackURL(stackID: id)
        if FileManager.default.fileExists(atPath: url.path), !force {
            throw StackStoreError.alreadyExists(id)
        }
        let record = StackRecord(stackID: id, baseBranch: baseBranch, remote: remote)
        try save(record, overwrite: true)
        return record
    }
}

private func normalizeID(_ id: String) throws -> String {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw StackStoreError.invalidID(id) }
    let ok = trimmed.allSatisfy { ch in
        ch.isLetter || ch.isNumber || ch == "-" || ch == "_" || ch == "."
    }
    guard ok else { throw StackStoreError.invalidID(id) }
    return trimmed
}
