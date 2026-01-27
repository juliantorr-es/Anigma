import XCTest
import CapsuleCore
import TelemetryCore
@testable import ContainerKit

final class ContainerKitTests: XCTestCase {
    
    var containerKit: ContainerKit!
    var diagnostics: DefaultCapsuleDiagnostics!
    var tempDirectory: String!
    
    override func setUp() async throws {
        diagnostics = DefaultCapsuleDiagnostics()
        containerKit = try ContainerKit(id: "test-containerkit", diagnostics: diagnostics)
        
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
    
    func testCreateZipArchive() async throws {
        // Create test files
        let testFile1Path = tempDirectory.appending("/test1.txt")
        let testFile2Path = tempDirectory.appending("/test2.txt")
        
        try "Test content 1".write(toFile: testFile1Path, atomically: true, encoding: .utf8)
        try "Test content 2".write(toFile: testFile2Path, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/test.zip")
        
        let result = try await containerKit.createArchive(
            from: [testFile1Path, testFile2Path],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.entriesProcessed, 2)
        XCTAssertGreaterThan(result.bytesProcessed, 0)
        XCTAssertEqual(result.metadata.creator, "ContainerKit Stub")
        XCTAssertEqual(result.metadata.totalEntries, 2)
        
        // Verify archive file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath))
    }
    
    func testExtractZipArchive() async throws {
        // First create a test archive
        let testFilePath = tempDirectory.appending("/test.txt")
        try "Test extraction content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/test.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFilePath],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Now extract it
        let extractDirectory = tempDirectory.appending("/extracted")
        let extractResult = try await containerKit.extractArchive(
            from: archivePath,
            to: extractDirectory
        )
        
        XCTAssertTrue(extractResult.success)
        XCTAssertGreaterThan(extractResult.entriesProcessed, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDirectory))
    }
    
    func testListArchiveContents() async throws {
        // Create a test archive first
        let testFilePath = tempDirectory.appending("/test.txt")
        try "Test listing content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/test.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFilePath],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // List contents
        let entries = try await containerKit.listArchiveContents(archivePath)
        
        XCTAssertGreaterThan(entries.count, 0)
        XCTAssertEqual(entries.first?.path, "test.txt")
        XCTAssertFalse(entries.first?.isDirectory ?? true)
    }
    
    func testCreateArchiveWithDirectory() async throws {
        // Create test directory structure
        let testDirPath = tempDirectory.appending("/testdir")
        try FileManager.default.createDirectory(atPath: testDirPath, withIntermediateDirectories: true)
        
        let testFileInDirPath = testDirPath.appending("/file_in_dir.txt")
        try "File in directory".write(toFile: testFileInDirPath, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/directory_test.zip")
        
        let result = try await containerKit.createArchive(
            from: [testDirPath],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.entriesProcessed, 1) // Directory + file
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath))
    }
    
    func testCompressionLevels() async throws {
        let testFilePath = tempDirectory.appending("/compression_test.txt")
        let largeContent = String(repeating: "This is test content for compression testing. ", count: 100)
        try largeContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let levels: [CompressionLevel] = [.none, .fastest, .normal, .maximum]
        
        for level in levels {
            let archivePath = tempDirectory.appending("/compression_test_\(level.rawValue).zip")
            
            let result = try await containerKit.createArchive(
                from: [testFilePath],
                to: archivePath,
                containerType: .zip,
                compressionLevel: level
            )
            
            XCTAssertTrue(result.success)
            XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath))
            
            if level == .none {
                XCTAssertEqual(result.metadata.compressionRatio, 1.0)
            } else {
                XCTAssertNotEqual(result.metadata.compressionRatio, 1.0)
            }
        }
    }
    
    func testValidateArchive() async throws {
        // Create a test archive
        let testFilePath = tempDirectory.appending("/validation_test.txt")
        try "Validation test content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/validation_test.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFilePath],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Validate the archive
        let validationResult = await containerKit.validateArchive(archivePath)
        
        // Stub validation should succeed with warning
        XCTAssertTrue(validationResult.isValid)
        XCTAssertEqual(validationResult.issues.count, 0)
        XCTAssertGreaterThanOrEqual(validationResult.warnings.count, 0)
    }
    
    func testGetArchiveMetadata() async throws {
        // Create a test archive
        let testFilePath = tempDirectory.appending("/metadata_test.txt")
        try "Metadata test content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        let archivePath = tempDirectory.appending("/metadata_test.zip")
        let createResult = try await containerKit.createArchive(
            from: [testFilePath],
            to: archivePath,
            containerType: .zip
        )
        
        XCTAssertTrue(createResult.success)
        
        // Get metadata
        let metadata = try await containerKit.getArchiveMetadata(archivePath)
        
        XCTAssertEqual(metadata.creator, "ContainerKit Stub")
        XCTAssertEqual(metadata.totalEntries, 1)
        XCTAssertGreaterThan(metadata.totalSize, 0)
    }
    
    func testUnsupportedArchiveTypes() async {
        let archivePath = tempDirectory.appending("/test.tar")
        
        // Should throw unsupported operation for non-ZIP types
        do {
            _ = try await containerKit.createArchive(
                from: [tempDirectory],
                to: archivePath,
                containerType: .tar
            )
            XCTFail("Should have thrown unsupported operation error")
        } catch let error as CapsuleError {
            if case .unsupportedOperation(let operation, _) = error {
                XCTAssertEqual(operation, "createArchive")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testGetSupportedContainerTypes() {
        let supportedTypes = containerKit.getSupportedContainerTypes()
        
        XCTAssertTrue(supportedTypes.contains(.zip))
        XCTAssertTrue(supportedTypes.contains(.tar))
        
        // Other types should not be supported in Tier 1 stub
        XCTAssertFalse(supportedTypes.contains(.sevenZ))
        XCTAssertFalse(supportedTypes.contains(.rar))
        XCTAssertFalse(supportedTypes.contains(.iso))
        XCTAssertFalse(supportedTypes.contains(.dmg))
    }
    
    func testHealthStatus() {
        let health = containerKit.healthStatus()
        
        XCTAssertEqual(health["containerkit_id"], "test-containerkit")
        XCTAssertEqual(health["status"], "healthy")
        XCTAssertNotNil(health["timestamp"])
        XCTAssertTrue(health["supported_types"]?.contains("zip") == true)
        XCTAssertTrue(health["supported_types"]?.contains("tar") == true)
    }
    
    func testErrorHandlingEmptySourcePaths() async {
        let archivePath = tempDirectory.appending("/error_test.zip")
        
        do {
            _ = try await containerKit.createArchive(
                from: [],
                to: archivePath,
                containerType: .zip
            )
            XCTFail("Should have thrown invalidInput error")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "sourcePaths")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testErrorHandlingNonExistentPath() async {
        let archivePath = tempDirectory.appending("/error_test.zip")
        let nonExistentPath = "/path/that/does/not/exist.txt"
        
        do {
            _ = try await containerKit.createArchive(
                from: [nonExistentPath],
                to: archivePath,
                containerType: .zip
            )
            XCTFail("Should have thrown invalidInput error")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "sourcePaths")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testErrorHandlingEmptyOutputPath() async {
        let testFilePath = tempDirectory.appending("/test.txt")
        try "Test content".write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        do {
            _ = try await containerKit.createArchive(
                from: [testFilePath],
                to: "",
                containerType: .zip
            )
            XCTFail("Should have thrown invalidInput error")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "outputPath")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}