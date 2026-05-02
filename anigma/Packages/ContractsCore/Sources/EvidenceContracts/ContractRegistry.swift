//
//  ContractRegistry.swift
//  ContractsCore
//
//  Registry that resolves contracts by identifier.
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import Foundation

/// Registry that resolves contracts by identifier.
public actor ContractRegistry {
    private var contracts: [ContractID: AnyContractSpec] = [:]

    public init() {}

    public func register<C: ContractSpec>(_ type: C.Type) {
        contracts[C.id] = AnyContractSpec(type)
    }

    public func resolve(_ id: ContractID) -> AnyContractSpec? {
        contracts[id]
    }
    
    public func allDescriptors() -> [ContractID] {
        Array(contracts.keys)
    }
}
