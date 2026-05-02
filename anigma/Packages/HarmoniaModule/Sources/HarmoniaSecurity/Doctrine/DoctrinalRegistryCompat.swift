//
//  DoctrinalRegistryCompat.swift
//  HarmoniaModule
//
//  Compatibility registry that avoids storing existential scout state.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore

public protocol DoctrinalScout: Sendable {
    var domain: DoctrineDomain { get }
    func scan(fileAt path: String) async throws -> [DoctrineViolation]
}

public actor DoctrinalScoutRegistry {
    private var includeCodeQuality = true
    private var includeBasicSecurity = true
    private var includeArchitecture = true
    private var includeLawCompliance = true

    public init(scouts: [any DoctrinalScout] = []) {
        for scout in scouts {
            switch scout.domain {
            case .quality:
                includeCodeQuality = true
            case .security:
                includeBasicSecurity = true
            case .architecture:
                includeArchitecture = true
            case .lawCompliance, .privacy, .accessibility:
                includeLawCompliance = true
            default:
                break
            }
        }
    }

    public func register(_ scout: any DoctrinalScout) {
        switch scout.domain {
        case .quality:
            includeCodeQuality = true
        case .security:
            includeBasicSecurity = true
        case .architecture:
            includeArchitecture = true
        case .lawCompliance, .privacy, .accessibility:
            includeLawCompliance = true
        default:
            break
        }
    }

    public func getScout(for domain: DoctrineDomain) -> (any DoctrinalScout)? {
        switch domain {
        case .quality where includeCodeQuality:
            return CodeQualityScout()
        case .security where includeBasicSecurity:
            return BasicSecurityScout()
        case .architecture where includeArchitecture:
            return ArchitectureScout()
        case .lawCompliance where includeLawCompliance,
             .privacy where includeLawCompliance,
             .accessibility where includeLawCompliance:
            return ConcreteLawComplianceScout()
        default:
            return nil
        }
    }

    public func getAllScouts() -> [any DoctrinalScout] {
        var scouts: [any DoctrinalScout] = []
        if includeCodeQuality { scouts.append(CodeQualityScout()) }
        if includeBasicSecurity { scouts.append(BasicSecurityScout()) }
        if includeArchitecture { scouts.append(ArchitectureScout()) }
        if includeLawCompliance { scouts.append(ConcreteLawComplianceScout()) }
        return scouts
    }

    public func scanFile(at path: String) async throws -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []

        if includeCodeQuality {
            violations.append(contentsOf: try await CodeQualityScout().scan(fileAt: path))
        }
        if includeBasicSecurity {
            violations.append(contentsOf: try await BasicSecurityScout().scan(fileAt: path))
        }
        if includeArchitecture {
            violations.append(contentsOf: try await ArchitectureScout().scan(fileAt: path))
        }
        if includeLawCompliance {
            violations.append(contentsOf: try await ConcreteLawComplianceScout().scan(fileAt: path))
        }

        return violations
    }

    public func scanDirectory(at path: String) async throws -> [DoctrineViolation] {
        let swiftFiles = enumeratedSwiftFiles(in: path)
        var violations: [DoctrineViolation] = []
        for absolutePath in swiftFiles {
            violations.append(contentsOf: try await scanFile(at: absolutePath))
        }
        return violations
    }

    nonisolated private func enumeratedSwiftFiles(in path: String) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return []
        }

        var swiftFiles: [String] = []
        for case let relativePath as String in enumerator {
            guard relativePath.hasSuffix(".swift") else { continue }
            let absolutePath = URL(fileURLWithPath: path).appendingPathComponent(relativePath).path
            swiftFiles.append(absolutePath)
        }

        return swiftFiles
    }
}
