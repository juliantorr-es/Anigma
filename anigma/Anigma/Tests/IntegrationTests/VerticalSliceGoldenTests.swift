import XCTest
import AnigmaDaemonCore
import TelemetryCore

final class VerticalSliceGoldenTests: XCTestCase {
    func testVerticalSlicePipelineOutputMatchesGoldenV1() async throws {
        let fixtures = try VerticalSliceFixtureLoader.load()
        XCTAssertEqual(fixtures.manifest.version, 1)

        let pipeline = VerticalSlicePipeline()
        let diagnostics = DefaultCapsuleDiagnostics()
        let request = fixtures.request
        let output = try await pipeline.execute(request: request, diagnostics: diagnostics)

        let normalizedOutput = VerticalSliceNormalization.normalize(output)
        let actual = try VerticalSliceNormalization.encodeJSON(normalizedOutput)
        let expected = try VerticalSliceNormalization.normalizeJSON(fixtures.expectedOutputData)

        XCTAssertEqual(actual, expected)
    }
}

private struct VerticalSliceManifest: Codable {
    let version: Int
    let name: String
    let description: String
    let requestFile: String
    let outputFile: String
}

private struct VerticalSliceRequestFixture: Codable {
    let jobID: String
    let sourcePath: String
    let instruction: String
    let text: String?
    let pdfDataBase64: String?
}

private struct VerticalSliceFixtures {
    let manifest: VerticalSliceManifest
    let request: VerticalSliceRequest
    let expectedOutputData: Data
}

private enum VerticalSliceFixtureLoader {
    static func load() throws -> VerticalSliceFixtures {
        let goldenRoot = findProjectRoot().appendingPathComponent("Tests/Golden/VerticalSlice/v1")
        let manifestData = try Data(contentsOf: goldenRoot.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(VerticalSliceManifest.self, from: manifestData)

        let requestData = try Data(contentsOf: goldenRoot.appendingPathComponent(manifest.requestFile))
        let requestFixture = try JSONDecoder().decode(VerticalSliceRequestFixture.self, from: requestData)

        let pdfData = requestFixture.pdfDataBase64.flatMap { Data(base64Encoded: $0) }
        let request = VerticalSliceRequest(
            jobID: requestFixture.jobID,
            sourcePath: requestFixture.sourcePath,
            instruction: requestFixture.instruction,
            text: requestFixture.text,
            pdfData: pdfData
        )

        let expectedOutputData = try Data(contentsOf: goldenRoot.appendingPathComponent(manifest.outputFile))
        return VerticalSliceFixtures(
            manifest: manifest,
            request: request,
            expectedOutputData: expectedOutputData
        )
    }

    private static func findProjectRoot() -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            let candidate = current.deletingLastPathComponent().appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.deletingLastPathComponent()
            }
            current.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

private enum VerticalSliceNormalization {
    static func normalize(_ output: VerticalSlicePipelineOutput) -> VerticalSlicePipelineOutput {
        let ranks = output.ranks.map {
            RankSummary(
                chunkID: $0.chunkID,
                fusedScore: round($0.fusedScore),
                lexicalScore: round($0.lexicalScore),
                embeddingScore: round($0.embeddingScore)
            )
        }
        let sections = output.renderPlan.sections.map {
            RenderPlanSection(
                chunkID: $0.chunkID,
                title: $0.title,
                highlight: $0.highlight,
                score: round($0.score)
            )
        }
        let renderPlan = RenderPlan(
            planID: output.renderPlan.planID,
            instruction: output.renderPlan.instruction,
            summary: output.renderPlan.summary,
            sections: sections
        )
        return VerticalSlicePipelineOutput(
            ingest: output.ingest,
            chunks: output.chunks,
            embeddings: output.embeddings,
            ranks: ranks,
            renderPlan: renderPlan,
            outputDigest: output.outputDigest
        )
    }

    static func encodeJSON(_ output: VerticalSlicePipelineOutput) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try normalizeJSON(encoder.encode(output))
    }

    static func normalizeJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
    }

    private static func round(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}
