//
//  Permission.swift
//  ContractsCore
//
//  Permission types for tool access.
//

import FoundationContracts
import AnigmaPrimitives
import Foundation

/// Permission types for tool access.
public enum Permission: String, Sendable, Codable, CaseIterable {
    case readFiles = "read_files"
    case writeFiles = "write_files"
    case modifyCode = "modify_code"
    case executeBuild = "execute_build"
    case writeArtifacts = "write_artifacts"
    case executeTests = "execute_tests"
    case readResults = "read_results"
    case readRepository = "read_repository"
    case writeRepository = "write_repository"
    case executeML = "execute_ml"
    case readModels = "read_models"
    case systemAccess = "system_access"

    public var description: String {
        switch self {
        case .readFiles:
            return "Read files"
        case .writeFiles:
            return "Write files"
        case .modifyCode:
            return "Modify code"
        case .executeBuild:
            return "Execute builds"
        case .writeArtifacts:
            return "Write artifacts"
        case .executeTests:
            return "Execute tests"
        case .readResults:
            return "Read results"
        case .readRepository:
            return "Read repository"
        case .writeRepository:
            return "Write repository"
        case .executeML:
            return "Execute ML operations"
        case .readModels:
            return "Read ML models"
        case .systemAccess:
            return "System access"
        }
    }
}
