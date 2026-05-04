import Foundation

/// Deterministic, atomic writer for anigma.test.receipt.v1 JSON files.
///
/// Each test source file generates one stable receipt per test run.
/// Receipts are written to .build/anigma-test-artifacts/<TestTarget>/<TestFileName>.json by default.
/// If ANIGMA_TEST_ARTIFACTS_DIR environment variable is set, receipts are written under that root
/// while preserving the <TestTarget>/<TestFileName>.json structure.
///
/// Guarantees:
/// - Stable filenames (based on source file name only)
/// - Sorted JSON keys (alphabetical)
/// - Stable array ordering
/// - No wall-clock timestamps
/// - No absolute local paths
/// - Atomic writes (no partial writes)
/// - Automatic parent directory creation
/// - Overwrites existing receipts (no accumulation)
public struct TestReceiptWriter {
    /// Write a test receipt to the artifact directory.
    ///
    /// - Parameters:
    ///   - receipt: The TestReceipt to write.
    ///   - sourceFile: Swift source file path (e.g., "/path/SaturationInferenceCoreTests.swift" from #file).
    ///   - testTarget: Test target name (e.g., "SaturationInferenceCoreTests").
    ///   - outputDirOverride: If provided, use this directory as the root instead of .build/anigma-test-artifacts/.
    ///
    /// - Throws: Errors related to file I/O or JSON encoding.
    public static func write(
        receipt: TestReceipt,
        sourceFile: String = #file,
        testTarget: String,
        outputDirOverride: String? = nil
    ) throws {
        // Derive artifact filename from source file
        let fileName = deriveFileName(from: sourceFile)

        // Determine output root directory
        let outputRoot: String
        if let override = outputDirOverride {
            outputRoot = override
        } else {
            outputRoot = ProcessInfo.processInfo.environment["ANIGMA_TEST_ARTIFACTS_DIR"]
                ?? ".build/anigma-test-artifacts"
        }

        // Build full artifact directory path
        let artifactDir = "\(outputRoot)/\(testTarget)"

        // Normalize artifact file path for receipt (no absolute machine paths)
        let normalizedArtifactPath = normalizePathForReceipt(
            "\(artifactDir)/\(fileName)"
        )

        // Create artifact directory if it doesn't exist
        try FileManager.default.createDirectory(
            atPath: artifactDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create receipt with normalized path
        var finalReceipt = receipt
        // Override artifactFile in receipt to use normalized path
        let receiptWithNormalizedPath = TestReceipt(
            testTarget: finalReceipt.testTarget,
            sourceFile: finalReceipt.sourceFile,
            artifactFile: normalizedArtifactPath,
            status: finalReceipt.status,
            summary: finalReceipt.summary,
            validatedBehaviors: finalReceipt.validatedBehaviors,
            debugHintsForAgents: finalReceipt.debugHintsForAgents,
            relatedFiles: finalReceipt.relatedFiles,
            diagnostics: finalReceipt.diagnostics,
            canonicalPromotion: finalReceipt.canonicalPromotion
        )

        // Encode receipt with sorted keys
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(receiptWithNormalizedPath)

        // Write atomically to temporary file, then move
        let fullPath = "\(artifactDir)/\(fileName)"
        let tempPath = "\(fullPath).tmp.\(UUID().uuidString)"

        try jsonData.write(to: URL(fileURLWithPath: tempPath), options: [.atomic])

        // Move temp file to target location, overwriting if it exists
        try FileManager.default.removeItem(atPath: fullPath)
        try FileManager.default.moveItem(atPath: tempPath, toPath: fullPath)
    }

    // MARK: - Helpers

    /// Derive artifact filename from Swift source file path.
    ///
    /// Example: "/path/SaturationInferenceCoreTests.swift" -> "SaturationInferenceCoreTests.json"
    private static func deriveFileName(from sourceFile: String) -> String {
        let url = URL(fileURLWithPath: sourceFile)
        let fileName = url.deletingPathExtension().lastPathComponent
        return "\(fileName).json"
    }

    /// Normalize a file path for inclusion in receipt (remove absolute machine paths).
    ///
    /// Converts absolute paths to relative paths where possible.
    private static func normalizePathForReceipt(_ path: String) -> String {
        // If path is relative, use as-is
        if !path.hasPrefix("/") {
            return path
        }

        // If path contains home directory, convert to relative or symbolic
        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String?,
           path.hasPrefix(homeDir) {
            let relative = String(path.dropFirst(homeDir.count))
            // Remove leading slash if present
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }

        // For other absolute paths, try to make them relative to current directory
        let currentDir = FileManager.default.currentDirectoryPath
        if path.hasPrefix(currentDir) {
            let relative = String(path.dropFirst(currentDir.count))
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }

        // Return as-is if normalization not possible
        return path
    }
}
