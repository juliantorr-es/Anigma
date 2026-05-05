//
//  DaemonWorkerRegistry.swift
//  AnigmaDaemonCore
//
//  Canonical worker registration + parity validation shared by daemon and CLI modes.
//

import AnigmaCore
import DatabaseCore
import Foundation

public struct WorkerRegistryParityReport: Sendable {
    public let missingKinds: [String]
    public let extraKinds: [String]

    public init(missingKinds: [String], extraKinds: [String]) {
        self.missingKinds = missingKinds
        self.extraKinds = extraKinds
    }

    public var isInParity: Bool {
        missingKinds.isEmpty && extraKinds.isEmpty
    }
}

public enum DaemonWorkerRegistry {
    public static var canonicalKinds: [String] {
        [
            ArtifactCopyWorker.kind,
            MemoryLeakWorker.kind,
            CPUBurnWorker.kind,
            PDFWorker.kind,
            LaTeXWorker.kind,
            TextChunkingWorker.kind,
            SemanticChunkingWorker.kind,
            CodeGenerationWorker.kind,
            ASTAnalysisWorker.kind,
            ASTTransformWorker.kind,
            CodeSearchWorker.kind,
            IndexingWorker.kind,
            TechDebtWorker.kind,
            AccessumWorker.kind,
            DiaplasionWorker.kind,
            WorktreeWorker.kind,
            GovernanceWorker.kind,
            MLInferWorker.kind,
            FFmpegWorker.kind,
            PandocWorker.kind,
            GnuPGWorker.kind,
            ImageMagickWorker.kind,
            TesseractWorker.kind,
            LibassWorker.kind,
            BiberWorker.kind,
            InkscapeWorker.kind,
            CtagsWorker.kind,
            NoOpWorker.kind,
            HarmoniaWorker.kind
        ].sorted()
    }

    @discardableResult
    public static func registerCanonicalWorkers(
        on registry: JobRegistry,
        database: any DatabaseExecutor,
        artifactAuthority: (any ArtifactAuthority)? = nil,
        evidenceAuthority: (any EvidenceAuthority)? = nil,
        configuration: DaemonConfiguration? = nil
    ) async -> WorkerRegistryParityReport {
        await registry.register(worker: ArtifactCopyWorker())
        await registry.register(worker: MemoryLeakWorker())
        await registry.register(worker: CPUBurnWorker())
        await registry.register(worker: PDFWorker())
        await registry.register(worker: LaTeXWorker())
        await registry.register(worker: TextChunkingWorker())
        await registry.register(worker: SemanticChunkingWorker())
        await registry.register(worker: CodeGenerationWorker())
        await registry.register(worker: ASTAnalysisWorker())
        await registry.register(worker: ASTTransformWorker())
        await registry.register(worker: CodeSearchWorker())
        await registry.register(worker: IndexingWorker(database: database, configuration: configuration))
        await registry.register(worker: TechDebtWorker())
        await registry.register(worker: AccessumWorker())
        await registry.register(worker: DiaplasionWorker())
        await registry.register(worker: WorktreeWorker())
        await registry.register(worker: GovernanceWorker())
        await registry.register(worker: MLInferWorker(configuration: configuration))
        await registry.register(worker: FFmpegWorker())
        await registry.register(worker: PandocWorker())
        await registry.register(worker: GnuPGWorker())
        await registry.register(worker: ImageMagickWorker())
        await registry.register(worker: TesseractWorker())
        await registry.register(worker: LibassWorker())
        await registry.register(worker: BiberWorker())
        await registry.register(worker: InkscapeWorker())
        await registry.register(worker: CtagsWorker())
        await registry.register(worker: NoOpWorker())
        await registry.register(
            worker: HarmoniaWorker(
                artifactAuthority: artifactAuthority,
                evidenceAuthority: evidenceAuthority
            )
        )
        return await validateParity(of: registry)
    }

    public static func validateParity(of registry: JobRegistry) async -> WorkerRegistryParityReport {
        let registeredKinds = Set(await registry.registeredKinds())
        let canonicalSet = Set(canonicalKinds)

        let missing = canonicalSet.subtracting(registeredKinds).sorted()
        let extra = registeredKinds.subtracting(canonicalSet).sorted()
        return WorkerRegistryParityReport(missingKinds: missing, extraKinds: extra)
    }
}
