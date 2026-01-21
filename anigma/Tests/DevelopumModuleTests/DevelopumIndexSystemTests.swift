//
//  DevelopumIndexSystemTests.swift
//  DevelopumModuleTests
//
//  Tests for DevelopumIndexSystem indexing operations.
//

import XCTest
import AnigmaCore
@testable import DevelopumModule

final class DevelopumIndexSystemTests: XCTestCase {

    private var world: World!
    private var mockDatabaseService: MockDevelopumDatabaseService!
    private var indexSystem: DevelopumIndexSystem!

    override func setUp() {
        super.setUp()
        world = World()
        mockDatabaseService = MockDevelopumDatabaseService()
        indexSystem = DevelopumIndexSystem(
            databaseService: mockDatabaseService,
            telemetryClient: nil
        )
    }

    override func tearDown() {
        world = nil
        mockDatabaseService = nil
        indexSystem = nil
        super.tearDown()
    }

    // MARK: - System Properties

    func testSystemName() {
        XCTAssertEqual(indexSystem.name, "DevelopumIndexSystem")
    }

    // MARK: - MIME Type Detection

    func testDetectMimeTypeSwift() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "main.swift"), "text/x-swift")
        XCTAssertEqual(indexSystem.detectMimeType(for: "Test.swift"), "text/x-swift")
    }

    func testDetectMimeTypeJavaScript() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "app.js"), "text/javascript")
        XCTAssertEqual(indexSystem.detectMimeType(for: "module.ts"), "text/typescript")
        XCTAssertEqual(indexSystem.detectMimeType(for: "component.tsx"), "text/typescript")
        XCTAssertEqual(indexSystem.detectMimeType(for: "react.jsx"), "text/javascript")
    }

    func testDetectMimeTypePython() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "script.py"), "text/x-python")
        XCTAssertEqual(indexSystem.detectMimeType(for: "utils.py"), "text/x-python")
    }

    func testDetectMimeTypeRust() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "lib.rs"), "text/x-rust")
    }

    func testDetectMimeTypeGo() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "main.go"), "text/x-go")
    }

    func testDetectMimeTypeJavaKotlin() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "Main.java"), "text/x-java")
        XCTAssertEqual(indexSystem.detectMimeType(for: "App.kt"), "text/x-kotlin")
    }

    func testDetectMimeTypeRuby() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "script.rb"), "text/x-ruby")
    }

    func testDetectMimeTypePHP() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "index.php"), "text/x-php")
    }

    func testDetectMimeTypeCfamily() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "header.h"), "text/x-c")
        XCTAssertEqual(indexSystem.detectMimeType(for: "source.cpp"), "text/x-c++")
        XCTAssertEqual(indexSystem.detectMimeType(for: "header.hpp"), "text/x-c++")
        XCTAssertEqual(indexSystem.detectMimeType(for: "objective.m"), "text/x-objc")
        XCTAssertEqual(indexSystem.detectMimeType(for: "objective.mm"), "text/x-objc++")
    }

    func testDetectMimeTypeShell() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "install.sh"), "text/x-shellscript")
        XCTAssertEqual(indexSystem.detectMimeType(for: "build.sh"), "text/x-shellscript")
    }

    func testDetectMimeTypeDataFormats() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "config.json"), "application/json")
        XCTAssertEqual(indexSystem.detectMimeType(for: "deployment.yaml"), "text/yaml")
        XCTAssertEqual(indexSystem.detectMimeType(for: "settings.yml"), "text/yaml")
        XCTAssertEqual(indexSystem.detectMimeType(for: "document.xml"), "text/xml")
        XCTAssertEqual(indexSystem.detectMimeType(for: "page.html"), "text/html")
        XCTAssertEqual(indexSystem.detectMimeType(for: "style.css"), "text/css")
        XCTAssertEqual(indexSystem.detectMimeType(for: "readme.md"), "text/markdown")
    }

    func testDetectMimeTypePlainText() {
        XCTAssertEqual(indexSystem.detectMimeType(for: "readme.txt"), "text/plain")
        XCTAssertEqual(indexSystem.detectMimeType(for: "unknown.xyz"), "text/plain")
        XCTAssertEqual(indexSystem.detectMimeType(for: "noextension"), "text/plain")
    }

    // MARK: - Keyword Detection

    func testSwiftKeywords() {
        XCTAssertTrue(indexSystem.isKeyword("func", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("var", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("struct", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("class", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("return", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("if", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("else", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("guard", languageId: "swift"))
        XCTAssertTrue(indexSystem.isKeyword("import", languageId: "swift"))
    }

    func testSwiftNonKeywords() {
        XCTAssertFalse(indexSystem.isKeyword("myFunction", languageId: "swift"))
        XCTAssertFalse(indexSystem.isKeyword("calculateTotal", languageId: "swift"))
        XCTAssertFalse(indexSystem.isKeyword("UserModel", languageId: "swift"))
        XCTAssertFalse(indexSystem.isKeyword("API_BASE_URL", languageId: "swift"))
    }

    func testTypeScriptKeywords() {
        XCTAssertTrue(indexSystem.isKeyword("function", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("const", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("let", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("async", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("await", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("export", languageId: "typescript"))
        XCTAssertTrue(indexSystem.isKeyword("import", languageId: "typescript"))
    }

    func testPythonKeywords() {
        XCTAssertTrue(indexSystem.isKeyword("def", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("class", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("return", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("if", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("elif", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("try", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("except", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("lambda", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("True", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("False", languageId: "python"))
        XCTAssertTrue(indexSystem.isKeyword("None", languageId: "python"))
    }

    func testUnknownLanguageKeywords() {
        XCTAssertFalse(indexSystem.isKeyword("function", languageId: "unknown"))
        XCTAssertFalse(indexSystem.isKeyword("def", languageId: "unknown"))
    }

    // MARK: - Identifier Extraction

    func testExtractIdentifiersSwift() {
        let line = "func calculateTotal(items: [Item]) -> Double {"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "swift")

        XCTAssertTrue(identifiers.contains("calculateTotal"))
        XCTAssertTrue(identifiers.contains("items"))
        XCTAssertTrue(identifiers.contains("Item"))
        XCTAssertFalse(identifiers.contains("func"))
        XCTAssertFalse(identifiers.contains("Double"))
    }

    func testExtractIdentifiersWithShortIdentifiers() {
        let line = "let a = b + c"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "swift")

        XCTAssertFalse(identifiers.contains("a"))
        XCTAssertFalse(identifiers.contains("b"))
        XCTAssertFalse(identifiers.contains("c"))
    }

    func testExtractIdentifiersTypeScript() {
        let line = "const userName: string = await fetchData();"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "typescript")

        XCTAssertTrue(identifiers.contains("userName"))
        XCTAssertTrue(identifiers.contains("fetchData"))
        XCTAssertFalse(identifiers.contains("const"))
        XCTAssertFalse(identifiers.contains("string"))
        XCTAssertFalse(identifiers.contains("await"))
    }

    func testExtractIdentifiersPython() {
        let line = "def process_items(items_list: List[str]) -> None:"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "python")

        XCTAssertTrue(identifiers.contains("process_items"))
        XCTAssertTrue(identifiers.contains("items_list"))
        XCTAssertFalse(identifiers.contains("def"))
        XCTAssertFalse(identifiers.contains("List"))
        XCTAssertFalse(identifiers.contains("None"))
    }

    func testExtractIdentifiersEmptyLine() {
        let identifiers = indexSystem.extractIdentifiers(from: "   ", languageId: "swift")
        XCTAssertTrue(identifiers.isEmpty)
    }

    func testExtractIdentifiersNoIdentifiers() {
        let line = "123 456 789"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "swift")
        XCTAssertTrue(identifiers.isEmpty)
    }

    func testExtractIdentifiersMultipleOnSameLine() {
        let line = "class UserRepository implements IUserRepository {"
        let identifiers = indexSystem.extractIdentifiers(from: line, languageId: "swift")

        XCTAssertTrue(identifiers.contains("UserRepository"))
        XCTAssertTrue(identifiers.contains("IUserRepository"))
        XCTAssertFalse(identifiers.contains("class"))
        XCTAssertFalse(identifiers.contains("implements"))
    }

    // MARK: - Index Job Processing

    func testUpdateWithNoJobs() async {
        await indexSystem.update(world: world)

        XCTAssertTrue(mockDatabaseService.savedArtifacts.isEmpty)
    }

    func testConcurrentJobLimit() async {
        let entity = await world.createEntity()
        await world.addComponent(entity, IndexJobComponent(jobId: "job1", filePath: "file1.swift", status: .pending))
        await world.addComponent(entity, RepoSessionComponent(id: UUID(), repoPath: "/test/repo"))
        await world.addComponent(entity, OpenFileComponent(filePath: "file1.swift", languageId: "swift"))

        let entity2 = await world.createEntity()
        await world.addComponent(entity2, IndexJobComponent(jobId: "job2", filePath: "file2.swift", status: .pending))
        await world.addComponent(entity2, RepoSessionComponent(id: UUID(), repoPath: "/test/repo"))
        await world.addComponent(entity2, OpenFileComponent(filePath: "file2.swift", languageId: "swift"))

        await indexSystem.update(world: world)

        let job1 = await world.getComponent(entity, IndexJobComponent.self)
        let job2 = await world.getComponent(entity2, IndexJobComponent.self)

        XCTAssertEqual(job1?.status, .running)
        XCTAssertEqual(job2?.status, .pending)
    }

    // MARK: - Mock Components

    private struct IndexJobComponent: Component {
        let jobId: String
        var filePath: String
        var status: JobStatus
        var startedAt: Date?
        var completedAt: Date?
        var durationMs: Int?
        var errorMessage: String?

        enum JobStatus: String, Codable {
            case pending, running, completed, failed
        }
    }

    private struct OpenFileComponent: Component {
        let filePath: String
        let languageId: String
    }
}

// MARK: - Mock Database Service

final class MockDevelopumDatabaseService {
    var savedArtifacts: [IndexArtifactRecord] = []
    var markedStale: [(repoId: UUID, filePath: String)] = []
    var deletedStale: [Date] = []

    func saveIndexArtifact(_ artifact: IndexArtifactRecord) async throws {
        savedArtifacts.append(artifact)
    }

    func markIndexArtifactsStale(repoId: UUID, filePath: String) async throws {
        markedStale.append((repoId, filePath))
    }

    func deleteStaleIndexArtifacts(olderThan date: Date) async throws {
        deletedStale.append(date)
    }
}
