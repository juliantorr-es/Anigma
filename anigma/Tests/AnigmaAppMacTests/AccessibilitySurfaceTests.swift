import Combine
import XCTest
@testable import AnigmaAppMac
import ContractsCore

@MainActor
final class AccessibilitySurfaceTests: XCTestCase {
    func testProgressViewModelAnnouncesAccessibleState() {
        let subject = PassthroughSubject<OperationResult<Int>, Never>()
        let viewModel = OperationProgressViewModel<Int>(publisher: subject.eraseToAnyPublisher(), label: "Test Operation")

        subject.send(
            OperationResult(
                kind: "test",
                state: .running,
                payload: nil,
                progress: .init(percent: 40, message: "Processing"),
                failure: nil
            )
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(viewModel.progressValue, 40)
        XCTAssertEqual(viewModel.statusText, "Processing")

        subject.send(
            OperationResult(
                kind: "test",
                state: .failure,
                payload: nil,
                progress: nil,
                failure: .init(code: "FAIL", message: "Broken")
            )
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(viewModel.statusText, "Broken")

        subject.send(
            OperationResult(
                kind: "test",
                state: .success,
                payload: nil,
                progress: .init(percent: 100, message: "Done"),
                failure: nil
            )
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(viewModel.progressValue, 100)
        XCTAssertEqual(viewModel.statusText, "Completed")
    }

    func testProgressViewModelAnnouncesMilestones() {
        let subject = PassthroughSubject<OperationResult<Int>, Never>()
        var announcements: [String] = []
        let original = OperationProgressAnnouncement.handler
        OperationProgressAnnouncement.handler = { announcements.append($0) }
        defer { OperationProgressAnnouncement.handler = original }

        let viewModel = OperationProgressViewModel<Int>(publisher: subject.eraseToAnyPublisher(), label: "Milestone Op")

        subject.send(
            OperationResult(
                kind: "test",
                state: .running,
                payload: nil,
                progress: .init(percent: 5, message: "start"),
                failure: nil
            )
        )

        subject.send(
            OperationResult(
                kind: "test",
                state: .running,
                payload: nil,
                progress: .init(percent: 15, message: "mid"),
                failure: nil
            )
        )

        subject.send(
            OperationResult(
                kind: "test",
                state: .success,
                payload: nil,
                progress: .init(percent: 100, message: "done"),
                failure: nil
            )
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        _ = viewModel // keep alive

        XCTAssertFalse(announcements.isEmpty)
        XCTAssertTrue(announcements.contains { $0.contains("5%") || $0.contains("15%") })
        XCTAssertTrue(announcements.contains { $0.lowercased().contains("completed") })
    }
}
