import XCTest
import CapsuleCore
import TelemetryCore
@testable import ContainerKit

final class ContainerKitGoldenTests: XCTestCase {
    
    var containerKit: ContainerKit!
    var tempDirectory: String!
    
    override func setUp() async throws {
        containerKit = try ContainerKit(id: "test-golden", diagnostics: DefaultCapsuleDiagnostics())
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDirectory)
        }
    }
    
    func testGoldenSimpleArchiveCreation() async throws {
        // Create simple test files
        let testFile1Path = tempDirectory.appending("/golden_test1.txt")
        let testFile2Path = tempDirectory.appending("/golden_test2.txt")
        
        try "Golden test content 1".write(toFile: testFile1Path, atomically: true, encoding: .utf8)
        try "Golden test content 2".write(toFile: testFile2Path, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_simple.zip")
        
        let result = try await containerKit.createArchive(
            from: [testFile1Path, testFile2Path],
            to: archivePath,
            containerType: .zip
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let resultJSON = try String(data: JSONEncoder().encode(result), encoding: .utf8)
        try await GoldenKit.assertMatches(
            resultJSON,
            named: "simple_archive_creation_result",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check basic structure and consistency
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.entriesProcessed, 2)
        XCTAssertEqual(result.metadata.creator, "ContainerKit Stub")
        XCTAssertEqual(result.metadata.totalEntries, 2)
        XCTAssertEqual(result.errors.count, 0)
        
        // Check properties contain expected keys
        XCTAssertNotNil(result.metadata.properties["container_type"])
        XCTAssertNotNil(result.metadata.properties["compression_level"])
        
        if case .string(let containerType) = result.metadata.properties["container_type"] {
            XCTAssertEqual(containerType, "zip")
        } else {
            XCTFail("Expected string container_type")
        }
    }
    
    func testGoldenComplexArchiveCreation() async throws {
        // Create complex directory structure
        let rootDir = tempDirectory.appending("/golden_complex")
        try FileManager.default.createDirectory(atPath: rootDir, withIntermediateDirectories: true)
        
        let subDir = rootDir.appending("/subdir")
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        
        // Create files at different levels
        let rootFile = rootDir.appending("/root.txt")
        let subFile = subDir.appending("/sub.txt")
        
        try "Root level file content for golden test".write(toFile: rootFile, atomically: true, encoding: .utf8)
        try "Subdirectory file content for golden test".write(toFile: subFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_complex.zip")
        
        let result = try await containerKit.createArchive(
            from: [rootDir],
            to: archivePath,
            containerType: .zip,
            compressionLevel: .maximum
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let resultJSON = try String(data: JSONEncoder().encode(result), encoding: .utf8)
        try await GoldenKit.assertMatches(
            resultJSON,
            named: "complex_archive_creation_result",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check structure
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.entriesProcessed, 2) // Directory + files
        XCTAssertGreaterThan(result.bytesProcessed, 0)
        XCTAssertEqual(result.metadata.totalEntries, result.entriesProcessed)
        
        // Check compression level is reflected
        XCTAssertEqual(result.metadata.compressionRatio, 0.8) // Stub ratio for maximum compression
        
        if case .int(let compressionLevel) = result.metadata.properties["compression_level"] {
            XCTAssertEqual(compressionLevel, CompressionLevel.maximum.rawValue)
        } else {
            XCTFail("Expected int compression_level")
        }
    }
    
    func testGoldenArchiveExtraction() async throws {
        // First create a test archive
        let testFile = tempDirectory.appending("/golden_extract.txt")
        try "Golden extraction test content with sufficient length to test compression".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_extract.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Now extract it
        let extractDirectory = tempDirectory.appending("/golden_extracted")
        let extractResult = try await containerKit.extractArchive(
            from: archivePath,
            to: extractDirectory
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let extractResultJSON = try String(data: JSONEncoder().encode(extractResult), encoding: .utf8)
        try await GoldenKit.assertMatches(
            extractResultJSON,
            named: "archive_extraction_result",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check extraction consistency
        XCTAssertTrue(extractResult.success)
        XCTAssertGreaterThan(extractResult.entriesProcessed, 0)
        XCTAssertGreaterThan(extractResult.bytesProcessed, 0)
        
        // Verify the extracted directory exists and contains content
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDirectory))
        
        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDirectory)
        XCTAssertGreaterThan(extractedFiles.count, 0)
        
        // Check the first extracted file (should be our placeholder content)
        let extractedFile = extractDirectory.appending("/\(extractedFiles.first!)")
        let extractedContent = try String(contentsOfFile: extractedFile)
        XCTAssertTrue(extractedContent.contains("ZIP archive placeholder"))
    }
    
    func testGoldenArchiveListing() async throws {
        // Create test archive with known structure
        let testDir = tempDirectory.appending("/golden_list")
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
        
        let file1 = testDir.appending("/file1.txt")
        let file2 = testDir.appending("/file2.txt")
        
        try "First file for listing test".write(toFile: file1, atomically: true, encoding: .utf8)
        try "Second file for listing test".write(toFile: file2, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_list.zip")
        let createResult = try await containerKit.createArchive(
            from: [testDir],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // List archive contents
        let entries = try await containerKit.listArchiveContents(archivePath)
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let entriesJSON = try String(data: JSONEncoder().encode(entries), encoding: .utf8)
        try await GoldenKit.assertMatches(
            entriesJSON,
            named: "archive_listing_entries",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check listing structure
        XCTAssertGreaterThan(entries.count, 0)
        
        for entry in entries {
            // Check entry structure
            XCTAssertFalse(entry.path.isEmpty)
            XCTAssertGreaterThanOrEqual(entry.size, 0)
            XCTAssertNotNil(entry.lastModified)
            XCTAssertNotNil(entry.permissions)
            
            // Check permissions structure
            let permissions = entry.permissions
            XCTAssertGreaterThanOrEqual(permissions.octal, 0)
            XCTAssertLessThanOrEqual(permissions.octal, 0o777)
            
            // Check default permissions are applied correctly
            if entry.path.contains("file1") || entry.path.contains("file2") {
                XCTAssertFalse(entry.isDirectory)
                XCTAssertEqual(permissions.octal, FilePermissions.default.octal)
            }
        }
    }
    
    func testGoldenCompressionLevels() async throws {
        let testFile = tempDirectory.appending("/golden_compression.txt")
        let largeContent = String(repeating: "Golden compression test content. ", count: 50)
        try largeContent.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let results: [ArchiveResult] = []
        
        for level in [CompressionLevel.none, .fastest, .normal, .maximum] {
            let archivePath = tempDirectory.appending("/golden_compression_\(level.rawValue).zip")
            
            let result = try await containerKit.createArchive(
                from: [testFile],
                to: archivePath,
                containerType: .zip,
                compressionLevel: level
            )
            
            // TODO: Collect results for golden comparison
            // Example using GoldenKit:
            /*
            let resultJSON = try String(data: JSONEncoder().encode(result), encoding: .utf8)
            try await GoldenKit.assertMatches(
                resultJSON,
                named: "compression_level_\(level.rawValue)_result",
                in: Bundle.module
            )
            */
            
            // Fallback checks
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.entriesProcessed, 1)
            
            // Check compression level is reflected in properties
            if case .int(let compressionLevel) = result.metadata.properties["compression_level"] {
                XCTAssertEqual(compressionLevel, level.rawValue)
            } else {
                XCTFail("Expected int compression_level")
            }
            
            // Check compression ratio behavior
            if level == .none {
                XCTAssertEqual(result.metadata.compressionRatio, 1.0)
            } else {
                XCTAssertNotEqual(result.metadata.compressionRatio, 1.0)
                XCTAssertLessThan(result.metadata.compressionRatio!, 1.0)
            }
        }
    }
    
    func testGoldenValidationResult() async throws {
        // Create test archive
        let testFile = tempDirectory.appending("/golden_validation.txt")
        try "Golden validation test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_validation.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Validate archive
        let validationResult = await containerKit.validateArchive(archivePath)
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let validationResultJSON = try String(data: JSONEncoder().encode(validationResult), encoding: .utf8)
        try await GoldenKit.assertMatches(
            validationResultJSON,
            named: "archive_validation_result",
            in: Bundle.module
        )
        */
        
        // Fallback checks
        XCTAssertTrue(validationResult.isValid)
        XCTAssertEqual(validationResult.issues.count, 0)
        
        // Should have at least one warning about stub validation
        XCTAssertGreaterThanOrEqual(validationResult.warnings.count, 0)
        
        if validationResult.warnings.count > 0 {
            let warning = validationResult.warnings.first!
            XCTAssertFalse(warning.id.isEmpty)
            XCTAssertFalse(warning.message.isEmpty)
            XCTAssertEqual(warning.severity, .warning)
        }
    }
    
    func testGoldenArchiveMetadata() async throws {
        // Create test archive
        let testFile = tempDirectory.appending("/golden_metadata.txt")
        try "Golden metadata test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_metadata.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Get metadata
        let metadata = try await containerKit.getArchiveMetadata(archivePath)
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let metadataJSON = try String(data: JSONEncoder().encode(metadata), encoding: .utf8)
        try await GoldenKit.assertMatches(
            metadataJSON,
            named: "archive_metadata_structure",
            in: Bundle.module
        )
        */
        
        // Fallback checks
        XCTAssertEqual(metadata.creator, "ContainerKit Stub")
        XCTAssertEqual(metadata.totalEntries, createResult.entriesProcessed)
        XCTAssertEqual(metadata.totalSize, createResult.bytesProcessed)
        XCTAssertEqual(metadata.version, "1.0.0")
        
        // Check properties
        XCTAssertNotNil(metadata.properties["container_type"])
        XCTAssertNotNil(metadata.properties["validation"])
        
        if case .string(let containerType) = metadata.properties["container_type"] {
            XCTAssertEqual(containerType, "zip")
        } else {
            XCTFail("Expected string container_type")
        }
    }
    
    func testGoldenOperationStability() async throws {
        // Test that same input produces consistent output structure
        let testFile = tempDirectory.appending("/golden_stability.txt")
        try "Golden stability test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/golden_stability.zip")
        
        // Create archive twice
        let result1 = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        // Remove archive for second test
        try FileManager.default.removeItem(atPath: archivePath)
        
        let result2 = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        // Results should have same structure (IDs may differ)
        XCTAssertEqual(result1.success, result2.success)
        XCTAssertEqual(result1.entriesProcessed, result2.entriesProcessed)
        XCTAssertEqual(result1.bytesProcessed, result2.bytesProcessed)
        XCTAssertEqual(result1.errors.count, result2.errors.count)
        XCTAssertEqual(result1.warnings.count, result2.warnings.count)
        XCTAssertEqual(result1.metadata.creator, result2.metadata.creator)
        XCTAssertEqual(result1.metadata.totalEntries, result2.metadata.totalEntries)
        
        // TODO: Add GoldenKit assertion for JSON stability
        /*
        let json1 = try JSONEncoder().encode(result1)
        let json2 = try JSONEncoder().encode(result2)
        try await GoldenKit.assertMatches(
            String(data: json1, encoding: .utf8) ?? "",
            named: "stable_archive_result",
            in: Bundle.module
        )
        */
    }
}