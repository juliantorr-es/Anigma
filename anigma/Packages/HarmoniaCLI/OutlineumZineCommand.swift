//
//  OutlineumZineCommand.swift
//  HarmoniaCLI
//
//  TRUTHFUL implementation using real ECS systems from OutlineumModule.
//

import ArgumentParser
import AnigmaCore
import AnigmaPrimitives
import CryptoKit
import Foundation
import OutlineumModule

#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct OutlineumZine: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "outlineum-zine",
            abstract: "Generates the Outlineum zine artifact with deterministic provenance."
        )
    }

    @Option(
        name: .shortAndLong,
        help: "Recipe spec JSON (default: \(OutlineumModuleResources.canonicalSpecRelativePath); override: ANIGMA_OUTLINEUM_SPEC)."
    )
    var spec: String?

    @Option(
        name: [.short, .customLong("output-base")],
        help: "Base directory for artifacts (default: Artifacts/outlineum/zine)."
    )
    var output: String = "Artifacts/outlineum/zine"

    public init() {}

    private static let specOverrideEnvironmentKey = "ANIGMA_OUTLINEUM_SPEC"

    public func run() async throws {
        let repoRoot = try Self.repositoryRoot()
        let specURL = try Self.resolveSpecURL(specOption: spec, repoRoot: repoRoot)
        let recipe = try ZineRecipeSpec.load(from: specURL)
        let pipelineVersion = OutlineumModuleVersion.string
        let inputHash = try Self.computeInputHash(for: recipe, specURL: specURL)

        let artifactDir = try Self.artifactDirectory(
            base: URL(fileURLWithPath: output, relativeTo: repoRoot),
            pipelineVersion: pipelineVersion,
            inputHash: inputHash
        )

        let world = World()
        
        let normalizedDir = artifactDir.appendingPathComponent("normalized", isDirectory: true)
        let outlinesDir = artifactDir.appendingPathComponent("outlines", isDirectory: true)
        let zinesDir = artifactDir.appendingPathComponent("zines", isDirectory: true)

        // 1. Create page entities
        var pageEntityIds: [EntityId] = []
        for imagePath in recipe.images {
            let resolved = try Self.resolveImageURL(imagePath, specURL: specURL)
            let pageEntity = await world.createEntity()
            await world.addComponent(pageEntity, ImageComponent(originalPath: resolved.path))
            pageEntityIds.append(pageEntity)
        }

        // 2. Create zine entity
        let zineEntity = await world.createEntity()
        let zineComponent = ZineComponent(
            title: recipe.title,
            specPath: Self.canonicalizePath(specURL, relativeTo: repoRoot),
            pageEntityIds: pageEntityIds,
            status: .draft,
            pipelineVersion: pipelineVersion,
            inputHash: inputHash,
            artifactDirectory: Self.canonicalizePath(artifactDir, relativeTo: repoRoot)
        )
        await world.addComponent(zineEntity, zineComponent)

        // 3. Run real Outlineum systems
        let ingest = IngestSystem(workDirectory: normalizedDir)
        let outline = OutlineSystem(workDirectory: outlinesDir, enableVectorization: false)
        let qa = OutlineQASystem()
        let layout = ZineLayoutSystem()
        let exporter = ZineExportSystem(
            workDirectory: zinesDir,
            config: ZineLayoutConfig()
        )

        let orderedSystems: [any System] = [ingest, outline, qa, layout, exporter]
        for system in orderedSystems {
            await world.runSystem(system)
        }

        // 4. Retrieve results
        guard let finalZine = await world.getComponent(zineEntity, ZineComponent.self) else {
            throw ValidationError("Failed to retrieve ZineComponent after processing.")
        }

        // 5. Generate provenance
        var pages: [OutlineumZinePageArtifact] = []
        for pageId in finalZine.pageEntityIds {
            let img = await world.getComponent(pageId, ImageComponent.self)
            let out = await world.getComponent(pageId, OutlineComponent.self)
            
            if let img, let out {
                pages.append(
                    OutlineumZinePageArtifact(
                        originalPath: Self.canonicalizePath(URL(fileURLWithPath: img.originalPath), relativeTo: repoRoot),
                        normalizedPath: Self.canonicalizePath(URL(fileURLWithPath: img.normalizedPath ?? ""), relativeTo: repoRoot),
                        outlinePath: Self.canonicalizePath(URL(fileURLWithPath: out.kidsOutlineRaster ?? out.adultOutlineRaster ?? ""), relativeTo: repoRoot)
                    )
                )
            }
        }

        let provenance = OutlineumZineProvenance(
            title: finalZine.title,
            version: recipe.version,
            specPath: finalZine.specPath ?? "",
            pipelineVersion: pipelineVersion,
            inputHash: inputHash,
            metadata: recipe.metadata ?? [:],
            pages: pages
        )

        let provenanceURL = artifactDir.appendingPathComponent("provenance.json")
        try Self.writeJSON(provenance, to: provenanceURL)

        // 6. Copy final PDF to root of artifact dir for convenience
        if let linearPdfPath = finalZine.linearPdfPath {
            let finalPdfURL = artifactDir.appendingPathComponent("zine.pdf")
            try? FileManager.default.removeItem(at: finalPdfURL)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: linearPdfPath), to: finalPdfURL)
        }

        print("Outlineum zine pipeline complete.")
        print("Artifacts:")
        print("- PDF: \(artifactDir.appendingPathComponent("zine.pdf").path)")
        print("- Provenance: \(provenanceURL.path)")
    }

    private static func repositoryRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let fileManager = FileManager.default
        while true {
            if fileManager.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                if fileManager.fileExists(atPath: current.appendingPathComponent("anigma/Package.swift").path) {
                    return current.appendingPathComponent("anigma")
                }
                throw ValidationError("Cannot locate Package.swift; ensure you run inside the repo.")
            }
            current = parent
        }
    }

    private static func resolveSpecURL(specOption: String?, repoRoot: URL) throws -> URL {
        if let specOption {
            let trimmed = specOption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ValidationError("The --spec option cannot be empty.")
            }
            return URL(fileURLWithPath: trimmed, relativeTo: repoRoot).standardizedFileURL
        } else if let envOverride = ProcessInfo.processInfo.environment[specOverrideEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !envOverride.isEmpty {
            return URL(fileURLWithPath: envOverride, relativeTo: repoRoot).standardizedFileURL
        } else {
            return try OutlineumModuleResources.urlForMinimalZineSpec()
        }
    }

    private static func artifactDirectory(base: URL, pipelineVersion: String, inputHash: String) throws -> URL {
        let target = base
            .appendingPathComponent(pipelineVersion, isDirectory: true)
            .appendingPathComponent(inputHash, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    private static func computeInputHash(for spec: ZineRecipeSpec, specURL: URL) throws -> String {
        var canonical = spec
        canonical.metadata = spec.metadata ?? [:]
        canonical.images = spec.images.sorted()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let specData = try encoder.encode(canonical)

        var hasher = SHA256()
        hasher.update(data: specData)

        let sortedImages = try spec.images
            .map { try resolveImageURL($0, specURL: specURL) }
            .sorted { $0.path < $1.path }

        for imageURL in sortedImages {
            let imageData = try Data(contentsOf: imageURL)
            hasher.update(data: imageData)
        }

        return hasher.finalize().hexString
    }

    private static func resolveImageURL(_ imagePath: String, specURL: URL) throws -> URL {
        let trimmed = imagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Outlineum spec contains an empty image path.")
        }

        let baseDir = specURL.deletingLastPathComponent()
        let resolved = URL(fileURLWithPath: trimmed, relativeTo: baseDir)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL

        guard FileManager.default.fileExists(atPath: resolved.path) else {
            throw ValidationError("Outlineum image missing at \(resolved.path)")
        }
        return resolved
    }

    private static func canonicalizePath(_ url: URL, relativeTo repoRoot: URL) -> String {
        let absolutePath = url.standardizedFileURL.path
        let repoPath = repoRoot.standardizedFileURL.path
        
        if absolutePath.hasPrefix(repoPath + "/") {
            return String(absolutePath.dropFirst(repoPath.count + 1))
        } else if absolutePath == repoPath {
            return ""
        } else {
            return absolutePath
        }
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }
}

private struct ZineRecipeSpec: Codable {
    var title: String
    var version: String?
    var images: [String]
    var metadata: [String: String]?

    static func load(from url: URL) throws -> ZineRecipeSpec {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ZineRecipeSpec.self, from: data)
    }
}

private struct OutlineumZineProvenance: Codable {
    let title: String
    let version: String?
    let specPath: String
    let pipelineVersion: String
    let inputHash: String
    let metadata: [String: String]
    let pages: [OutlineumZinePageArtifact]
}

private struct OutlineumZinePageArtifact: Codable {
    let originalPath: String
    let normalizedPath: String
    let outlinePath: String
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
