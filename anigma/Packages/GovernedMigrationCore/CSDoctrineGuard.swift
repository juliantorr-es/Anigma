//
//  CSDoctrineGuard.swift
//  GovernedMigrationCore
//
//  [Brief description of file purpose]
//

#if GOVERNED_CORE

import Foundation
import DoctrineCore

public final class CSDoctrineGuard {
    private let doctrinePack: any DoctrinePack
    private let violationLogger: any DoctrineViolationLogger

    public init(doctrinePack: any DoctrinePack, violationLogger: any DoctrineViolationLogger) {
        self.doctrinePack = doctrinePack
        self.violationLogger = violationLogger
    }

    public func check(file: URL) async -> Bool {
        do {
            let violations = try await doctrinePack.evaluate(for: file)

            guard !violations.isEmpty else {
                return true // Pass
            }

            for violation in violations {
                _ = await violationLogger.record(violation)
            }

            return false // Fail
        } catch {
            // In a real system, this error should be logged to a secure, observable channel.
            // For now, we print to stderr.
            fputs("Error during doctrine evaluation: \(error)\n", stderr)
            return false
        }
    }
}

#endif
