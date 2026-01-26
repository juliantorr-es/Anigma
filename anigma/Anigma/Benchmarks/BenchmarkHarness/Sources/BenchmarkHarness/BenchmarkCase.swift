import Foundation

public protocol BenchmarkCase {
    var name: String { get }
    var iterations: Int { get }

    func setUp() throws
    func run() throws
    func tearDown() throws
}

public extension BenchmarkCase {
    func setUp() throws {}
    func tearDown() throws {}
}
