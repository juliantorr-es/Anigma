import Foundation
import XCTest

@testable import AnigmaDaemonCore

final class WorkerRenderingTests: XCTestCase {
    func testPDFWorkerRendersPNG() async throws {
        guard WorkerTooling.findTool(named: "mutool") != nil else {
            throw XCTSkip("mutool not found on PATH; skipping PDF render test.")
        }

        let pdfData = minimalPDFData()
        let input = ArtifactRef(hash: "pdf-input", mediaType: "application/pdf", sizeBytes: UInt64(pdfData.count))
        let worker = PDFWorker()
        let outputs = try await worker.execute(
            inputs: [input],
            config: Data(),
            vaultData: [input.hash: pdfData]
        )

        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].mediaType, "image/png")
        XCTAssertTrue(outputs[0].data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    func testLaTeXWorkerBuildsPDF() async throws {
        guard WorkerTooling.findTool(named: "pdflatex") != nil else {
            throw XCTSkip("pdflatex not found on PATH; skipping LaTeX build test.")
        }

        let tex = """
        \\documentclass{article}
        \\begin{document}
        Hello, Anigma.
        \\end{document}
        """
        let texData = Data(tex.utf8)
        let input = ArtifactRef(hash: "tex-input", mediaType: "text/x-tex", sizeBytes: UInt64(texData.count))
        let worker = LaTeXWorker()
        let outputs = try await worker.execute(
            inputs: [input],
            config: Data(),
            vaultData: [input.hash: texData]
        )

        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].mediaType, "application/pdf")
        XCTAssertTrue(outputs[0].data.starts(with: Array("%PDF".utf8)))
    }

    private func minimalPDFData() -> Data {
        let pdf = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
        endobj
        4 0 obj
        << /Length 44 >>
        stream
        BT /F1 24 Tf 72 120 Td (Hello) Tj ET
        endstream
        endobj
        5 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        xref
        0 6
        0000000000 65535 f
        0000000010 00000 n
        0000000062 00000 n
        0000000120 00000 n
        0000000245 00000 n
        0000000337 00000 n
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        402
        %%EOF
        """
        return Data(pdf.utf8)
    }
}
