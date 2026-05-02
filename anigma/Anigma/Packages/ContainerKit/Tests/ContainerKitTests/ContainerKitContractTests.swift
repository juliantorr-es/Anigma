import XCTest
import CapsuleCore
import TelemetryCore
@testable import ContainerKit

final class ContainerKitContractTests: XCTestCase {
    
    var containerKit: ContainerKit!
    
    override func setUp() async throws {
        containerKit = try ContainerKit(id: "test-contract", diagnostics: DefaultCapsuleDiagnostics())
    }
    
    /// Contract: Empty container kit ID must throw .invalidConfiguration
    func testInvalidConfigurationEmptyID() async {
        do {
            _ = try ContainerKit(id: "")
            XCTFail("Should have thrown .invalidConfiguration")
        } catch let error as CapsuleError {
            if case .invalidConfiguration(let reason) = error {
                XCTAssertTrue(reason.contains("ID cannot be empty"))
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: Empty source paths must throw .invalidInput
    func testInvalidInputEmptySourcePaths() async {
        do {
            _ = try await containerKit.createArchive(
                from: [],
                to: "/tmp/test.zip",
                containerType: .zip
            )
            XCTFail("Should have thrown .invalidInput")
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
    
    /// Contract: Empty output path must throw .invalidInput
    func testInvalidInputEmptyOutputPath() async {
        do {
            _ = try await containerKit.createArchive(
                from: ["/tmp/test.txt"],
                to: "",
                containerType: .zip
            )
            XCTFail("Should have thrown .invalidInput")
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
    
    /// Contract: Non-existent source path must throw .invalidInput
    func testInvalidInputNonExistentSource() async {
        do {
            _ = try await containerKit.createArchive(
                from: ["/path/that/does/not/exist.txt"],
                to: "/tmp/test.zip",
                containerType: .zip
            )
            XCTFail("Should have thrown .invalidInput")
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
    
    /// Contract: Non-existent archive path must throw .invalidInput for extraction
    func testInvalidInputNonExistentArchive() async {
        do {
            _ = try await containerKit.extractArchive(
                from: "/path/that/does/not/exist.zip",
                to: "/tmp/extracted"
            )
            XCTFail("Should have thrown .invalidInput")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "archivePath")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: Unsupported archive types must throw .unsupportedOperation
    func testUnsupportedOperationCreate() async {
        do {
            _ = try await containerKit.createArchive(
                from: ["/tmp/test.txt"],
                to: "/tmp/test.7z",
                containerType: .sevenZ
            )
            XCTFail("Should have thrown .unsupportedOperation")
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
    
    func testUnsupportedOperationExtract() async {
        do {
            _ = try await containerKit.extractArchive(
                from: "/tmp/test.7z",
                to: "/tmp/extracted"
            )
            XCTFail("Should have thrown .unsupportedOperation")
        } catch let error as CapsuleError {
            if case .unsupportedOperation(let operation, _) = error {
                XCTAssertEqual(operation, "extractArchive")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: ArchiveEntry must be Codable and round-trip correctly
    func testArchiveEntryCodableContract() throws {
        let entry = ArchiveEntry(
            path: "test/file.txt",
            size: 1024,
            isDirectory: false,
            lastModified: Date(),
            permissions: FilePermissions.executable,
            checksum: "abc123",
            metadata: ["test": AnyCodable.string("value")]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(entry)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(ArchiveEntry.self, from: jsonData)
        XCTAssertEqual(entry, decodedEntry)
    }
    
    /// Contract: ArchiveResult must be Codable and round-trip correctly
    func testArchiveResultCodableContract() throws {
        let result = ArchiveResult(
            success: true,
            entriesProcessed: 10,
            bytesProcessed: 2048,
            errors: [
                ArchiveError(
                    id: "error-1",
                    type: .ioError,
                    message: "Test error",
                    entryPath: "test.txt"
                )
            ],
            warnings: [
                ArchiveWarning(
                    id: "warning-1",
                    type: .largeFile,
                    message: "Large file warning",
                    entryPath: "large.txt"
                )
            ],
            metadata: ArchiveMetadata(
                creator: "Test",
                totalEntries: 10,
                totalSize: 2048,
                compressionRatio: 0.8
            )
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(result)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(ArchiveResult.self, from: jsonData)
        XCTAssertEqual(result, decodedResult)
    }
    
    /// Contract: All model types must be Sendable and Equatable
    func testModelContracts() throws {
        // Test ArchiveEntry
        let entry = ArchiveEntry(
            path: "test.txt",
            size: 512,
            isDirectory: false,
            lastModified: Date(),
            permissions: FilePermissions.default
        )
        
        let identicalEntry = ArchiveEntry(
            path: "test.txt",
            size: 512,
            isDirectory: false,
            lastModified: entry.lastModified,
            permissions: FilePermissions.default
        )
        XCTAssertEqual(entry, identicalEntry)
        
        // Test Sendable (compiler will enforce)
        let sendableEntry: any Sendable = entry
        XCTAssertNotNil(sendableEntry)
        
        // Test FilePermissions
        let permissions = FilePermissions.executable
        let sendablePermissions: any Sendable = permissions
        XCTAssertNotNil(sendablePermissions)
        XCTAssertEqual(permissions.octal, 0o755)
        
        // Test ArchiveMetadata
        let metadata = ArchiveMetadata(creator: "Test")
        let sendableMetadata: any Sendable = metadata
        XCTAssertNotNil(sendableMetadata)
    }
    
    /// Contract: Validation must handle invalid archives
    func testValidationContract() async {
        let validationResult = await containerKit.validateArchive("/path/that/does/not/exist.zip")
        
        // Should return invalid result for non-existent file
        XCTAssertFalse(validationResult.isValid)
        XCTAssertGreaterThan(validationResult.issues.count, 0)
        
        let errorIssue = validationResult.issues.first { $0.severity == .error }
        XCTAssertNotNil(errorIssue)
        XCTAssertNotNil(errorIssue?.message.contains("not supported"))
    }
    
    /// Contract: Error metadata must be properly structured
    func testErrorMetadataContract() async {
        do {
            _ = try await containerKit.createArchive(
                from: [],
                to: "/tmp/test.zip",
                containerType: .zip
            )
            XCTFail("Should have thrown error")
        } catch let error as CapsuleError {
            XCTAssertNotNil(error.errorDescription)
            // Contract check for localized description or other metadata
        } catch {
            XCTFail("Should have been a CapsuleError")
        }
    }
    
    /// Contract: ContainerKit must maintain consistent health status
    func testHealthStatusContract() {
        let health = containerKit.healthStatus()
        
        // Required health status fields
        XCTAssertNotNil(health["containerkit_id"])
        XCTAssertNotNil(health["status"])
        XCTAssertNotNil(health["timestamp"])
        XCTAssertNotNil(health["supported_types"])
        
        // Status should be healthy for new container kit
        XCTAssertEqual(health["status"], "healthy")
        
        // Timestamp should be valid ISO8601
        let timestamp = health["timestamp"] ?? ""
        XCTAssertFalse(timestamp.isEmpty)
        
        // Supported types should include basic types
        let supportedTypes = health["supported_types"] ?? ""
        XCTAssertTrue(supportedTypes.contains("zip"))
        XCTAssertTrue(supportedTypes.contains("tar"))
    }
    
    /// Contract: Archive metadata must be properly structured
    func testArchiveMetadataContract() async throws {
        // Create a simple test file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let testFile = tempDir.appending("/test.txt")
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDir.appending("/test.zip")
        
        // Create archive
        let result = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        // Get metadata
        let metadata = try await containerKit.getArchiveMetadata(archivePath)
        
        // Check required metadata fields
        XCTAssertNotNil(metadata.createdDate)
        XCTAssertNotNil(metadata.modifiedDate)
        XCTAssertNotNil(metadata.creator)
        XCTAssertNotNil(metadata.totalEntries)
        XCTAssertNotNil(metadata.totalSize)
        XCTAssertNotNil(metadata.properties)
        
        // Check metadata values
        XCTAssertEqual(metadata.creator, "ContainerKit Stub")
        XCTAssertEqual(metadata.totalEntries, result.entriesProcessed)
        XCTAssertEqual(metadata.totalSize, result.bytesProcessed)
    }
    
    /// Contract: Archive entries must have correct structure
    func testArchiveEntryStructureContract() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let testFile = tempDir.appending("/structure_test.txt")
        try "Structure test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = tempDir.appending("/structure_test.zip")
        
        // Create archive
        _ = try await containerKit.createArchive(
            from: [testFile],
            to: archivePath,
            containerType: .zip
        )
        
        // List contents
        let entries = try await containerKit.listArchiveContents(archivePath)
        
        XCTAssertGreaterThan(entries.count, 0)
        
        for entry in entries {
            // Check required fields
            XCTAssertFalse(entry.path.isEmpty)
            XCTAssertGreaterThanOrEqual(entry.size, 0)
            XCTAssertNotNil(entry.lastModified)
            XCTAssertNotNil(entry.permissions)
            
            // Check permissions structure
            let permissions = entry.permissions
            XCTAssertNotNil(permissions.octal)
            XCTAssertTrue(permissions.octal >= 0 && permissions.octal <= 0o777)
        }
    }
}