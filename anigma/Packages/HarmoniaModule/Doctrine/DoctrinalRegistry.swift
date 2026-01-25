//
//  DoctrinalRegistry.swift
//  HarmoniaModule
//
//  Registry and protocol definitions for doctrine scouts.
//  Provides a reusable index over the various scanning actors and exposes helpers
//  for file/directory analysis.
//

@preconcurrency import Foundation
import DoctrineCore

public protocol DoctrinalScout: Sendable {
    /// Domain that the scout covers.
    var domain: DoctrineDomain { get }

    /// Scan a source file for doctrine violations.
    func scan(fileAt path: String) async throws -> [DoctrineViolation]
}

public actor DoctrinalScoutRegistry {
    private var scouts: [any DoctrinalScout]

    public init(scouts: [any DoctrinalScout] = [
        CodeQualityScout(),
        BasicSecurityScout(),
        ArchitectureScout(),
        ConcreteLawComplianceScout()
    ]) {
        self.scouts = scouts
    }

    public func register(_ scout: any DoctrinalScout) {
        scouts.append(scout)
    }

    public func getScout(for domain: DoctrineDomain) -> (any DoctrinalScout)? {
        scouts.first { $0.domain == domain }
    }

    public func getAllScouts() -> [any DoctrinalScout] {
        scouts
    }

    public func scanFile(at path: String) async throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        for scout in scouts {
            violations.append(contentsOf: try await scout.scan(fileAt: path))
        }
        return violations
    }

    public func scanDirectory(at path: String) async throws -> [DoctrineViolation] {
        let swiftFiles = enumeratedSwiftFiles(in: path)
        var violations: [DoctrineViolation] = []

        for file in swiftFiles {
            let fileViolations = try await scanFile(at: file)
            violations.append(contentsOf: fileViolations)
        }

        return violations
    }

    private func enumeratedSwiftFiles(in directory: String) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return []
        }

        var files: [String] = []
        for case let relativePath as String in enumerator {
            guard relativePath.hasSuffix(".swift") else { continue }
            let absolutePath = URL(fileURLWithPath: directory).appendingPathComponent(relativePath).path
            files.append(absolutePath)
        }

        return files
    }
}
