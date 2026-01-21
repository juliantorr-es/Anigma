//
//  ContractRegistry.swift
//  AnigmaCore
//
//  Registry that resolves contracts by identifier.
//  This actor lives in Tier 2 (Platform Runtime) as it manages state.
//

import Foundation
import ContractsCore

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
}
