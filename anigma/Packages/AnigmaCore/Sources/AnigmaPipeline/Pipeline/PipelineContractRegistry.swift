//
//  PipelineContractRegistry.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import AnigmaJobs
import ContractsCore
import Foundation
import DatabaseCore

/// Registers the default PDF pipeline contracts into a registry.
public func registerPDFPipelineContracts(into registry: ContractRegistry) async {
    await registry.register(PDFIngestContract.self)
    await registry.register(PDFSegmentContract.self)
    await registry.register(PDFExtractContract.self)
    await registry.register(PDFQACheckContract.self)
    await registry.register(EmbedTextContract.self)
    await registry.register(IndexEmbeddingsContract.self)
    await registry.register(HybridSearchContract.self)
    await registry.register(RunSwiftTestsContract.self)
    await registry.register(HardeningAttestationContract.self)
}

/// Creates a registry preloaded with the default PDF pipeline contracts.
public func makePDFPipelineRegistry() async -> ContractRegistry {
    let registry = ContractRegistry()
    await registerPDFPipelineContracts(into: registry)
    return registry
}
