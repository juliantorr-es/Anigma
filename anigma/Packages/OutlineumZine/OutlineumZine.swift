//
//  OutlineumZine.swift
//  OutlineumZine
//
//  [Brief description of file purpose]
//

import ArgumentParser
import AnigmaCore
import OutlineumModule
import Foundation
import CryptoKit

@main
struct OutlineumZineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outlineum-zine",
        abstract: "Generates the Outlineum zine artifact with deterministic provenance."
    )

    @Option(
        name: .shortAndLong,
        help: "Recipe spec JSON (default: Packages/OutlineumModule/TestFiles/zine-minimal/spec.json; override: ANIGMA_OUTLINEUM_SPEC)."
    )
    var spec: String?

    @Option(
        name: [.short, .customLong("output-base")],
        help: "Base directory for artifacts (default: Artifacts/outlineum/zine)."
    )
    var output: String = "Artifacts/outlineum/zine"

    private static let canonicalSpecRelativePath = "Packages/OutlineumModule/TestFiles/zine-minimal/spec.json"
    private static let specOverrideEnvironmentKey = "ANIGMA_OUTLINEUM_SPEC"

    func run() async throws {
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
        let aggregator = await world.createEntity()

        let normalizedDir = artifactDir.appendingPathComponent("normalized", isDirectory: true)
        let outlinesDir = artifactDir.appendingPathComponent("outlines", isDirectory: true)

        let recipeComponent = ZineRecipeComponent(
            title: recipe.title,
            version: recipe.version,
            specPath: specURL.path,
            imagePaths: recipe.images,
            metadata: recipe.metadata ?? [:],
            pipelineVersion: pipelineVersion,
            inputHash: inputHash
        )

        let zineComponent = ZineComponent(
            title: recipe.title,
            specPath: specURL.path,
            status: .draft,
            pipelineVersion: pipelineVersion,
            inputHash: inputHash
        )

        await world.addComponent(aggregator, recipeComponent)
        await world.addComponent(aggregator, zineComponent)

        for imagePath in recipe.images {
            let resolved = try Self.resolveImageURL(imagePath, specURL: specURL)
            let pageEntity = await world.createEntity()
            await world.addComponent(pageEntity, ImageComponent(originalPath: resolved.path))
        }

        let ingest = IngestSystem(workDirectory: normalizedDir)
        let outline = OutlineSystem(workDirectory: outlinesDir, enableVectorization: false)
        let qa = OutlineQASystem()
        let layout = ZineLayoutSystem()
        let exporter = ZineExportSystem(
            workDirectory: artifactDir,
            config: ZineLayoutConfig()
        )

        let orderedSystems: [any System] = [ingest, outline, qa, layout, exporter]

        for system in orderedSystems {
            await world.runSystem(system)
        }

        print("Outlineum zine pipeline complete.")
        print("Artifacts:")
        print("- PDF: \(artifactDir.appendingPathComponent("zine.pdf").path)")
        print("- Provenance: \(artifactDir.appendingPathComponent("provenance.json").path)")
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
                throw ValidationError("Cannot locate Package.swift; ensure you run inside the repo.")
            }
            current = parent
        }
    }

    private static func resolveSpecURL(specOption: String?, repoRoot: URL) throws -> URL {
        let sourcePath: String
        if let specOption {
            let trimmed = specOption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ValidationError("The --spec option cannot be empty.")
            }
            sourcePath = trimmed
        } else if let envOverride = ProcessInfo.processInfo.environment[specOverrideEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !envOverride.isEmpty {
            sourcePath = envOverride
        } else {
            sourcePath = canonicalSpecRelativePath
        }

        let resolved = URL(fileURLWithPath: sourcePath, relativeTo: repoRoot).standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            throw ValidationError(
                "Outlineum spec missing at \(resolved.path). Pass --spec or set \(specOverrideEnvironmentKey)."
            )
        }
        return resolved.resolvingSymlinksInPath().standardizedFileURL
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

        let digest = hasher.finalize()
        return digest.hexString
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

private extension SHA256.Digest {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
