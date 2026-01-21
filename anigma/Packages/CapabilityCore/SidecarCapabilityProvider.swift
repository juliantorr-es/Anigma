//
//  SidecarCapabilityProvider.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation

/// A provider that executes a sidecar tool to fulfill capabilities.
public protocol SidecarCapabilityProvider: CapabilityProvider {
    /// The path to the sidecar executable.
    var executablePath: String { get }

    /// Executes the sidecar with the given arguments and returns stdout.
    func execute(arguments: [String], input: Data?) async throws -> Data
}

extension SidecarCapabilityProvider {
    public func execute(arguments: [String], input: Data?) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        if let input = input {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            try inputPipe.fileHandleForWriting.write(contentsOf: input)
            try inputPipe.fileHandleForWriting.close()
        }

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CapabilityError.providerFailed(providerId, NSError(domain: "SidecarCapabilityProvider", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Sidecar exited with non-zero status \(process.terminationStatus)"]))
        }

        return try outputPipe.fileHandleForReading.readToEnd() ?? Data()
    }
}
