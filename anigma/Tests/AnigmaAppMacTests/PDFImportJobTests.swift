import Combine
import XCTest
import ContractsCore
@testable import AnigmaAppMac

@MainActor
final class PDFImportJobTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testOperationResultCodableRoundTrip() throws {
        let payload = PDFImportJob.ImportResult(
            fileName: "sample.pdf",
            byteCount: 10,
            pageCount: 1,
            textPreview: "sample",
            data: Data("sample".utf8)
        )
        let result = OperationResult(
            kind: "pdfImport",
            endTime: Date(),
            state: .success,
            payload: payload,
            progress: .init(percent: 100, message: "done"),
            failure: nil
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(OperationResult<PDFImportJob.ImportResult>.self, from: data)

        assertOperationValid(decoded, expectedKind: "pdfImport")
        XCTAssertEqual(decoded.payload, payload)
    }

    func testProgressEventsAreEmitted() async throws {
        let job = PDFImportJob()
        let pdfURL = try makeTempPDF()
        let expectation = XCTestExpectation(description: "progress updates")
        var percents: [Int] = []

        job.progressPublisher
            .sink { result in
                if let percent = result.progress?.percent {
                    percents.append(Int(percent))
                }
                if percents.count == 5 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let final = await job.importPDF(at: pdfURL, stageDelay: 0.05)
        await fulfillment(of: [expectation], timeout: 2.0)

        assertOperationValid(final, expectedKind: "pdfImport")
        XCTAssertEqual(Set(percents), Set([0, 25, 50, 75, 100]))
    }

    func testFailureProducesTypedError() async {
        let job = PDFImportJob()
        let missingURL = URL(fileURLWithPath: "/tmp/non-existent.pdf")

        let result = await job.importPDF(at: missingURL, stageDelay: 0.01)

        assertOperationValid(result, expectedKind: "pdfImport")
        XCTAssertEqual(result.failure?.code, "PDF_READ_ERROR")
    }

    func testIntegrationEmitsProgressForImport() async throws {
        let job = PDFImportJob()
        let pdfURL = try makeTempPDF()
        let expectation = XCTestExpectation(description: "integration progress")
        var sawProgress = false

        job.progressPublisher
            .sink { result in
                if result.progress != nil {
                    sawProgress = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        _ = await job.importPDF(at: pdfURL, stageDelay: 0.05)
        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertTrue(sawProgress)
    }

    private func makeTempPDF() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        let sample = """
        %PDF-1.4
        1 0 obj << /Type /Page >>
        stream
        Sample PDF text for testing.
        endstream
        endobj
        """
        try sample.data(using: .utf8)?.write(to: url)
        return url
    }
}
