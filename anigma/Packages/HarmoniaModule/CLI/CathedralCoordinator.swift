//
//  CathedralCoordinator.swift
//  HarmoniaModule
//
//  Cathedral coordinator for evidence enforcement demonstration.
//

@preconcurrency import Foundation

/// Cathedral coordinator configuration
public struct CathedralCoordinatorConfig: Sendable {
    public static let `default` = CathedralCoordinatorConfig()
    
    public init() {}
}

/// Cathedral coordinator protocol
public protocol CathedralCoordinatorProtocol: Sendable {
    var config: CathedralCoordinatorConfig { get }
    init(config: CathedralCoordinatorConfig)
}

/// Cathedral coordinator implementation
public struct CathedralCoordinator: CathedralCoordinatorProtocol {
    public let config: CathedralCoordinatorConfig
    
    public init(config: CathedralCoordinatorConfig = .default) {
        self.config = config
    }
}