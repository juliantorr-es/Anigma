import ArgumentParser
import Foundation
import OutlineumModule

@main
struct OutlineumZineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outlineum-zine",
        abstract: "Generates the Outlineum zine artifact (stub)."
    )

    func run() async throws {
        print("Outlineum zine pipeline is stubbed in this build.")
        print("Pipeline version: \(OutlineumModuleVersion.string)")
    }
}
