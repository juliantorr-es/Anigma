//
//  DevelopumIndexSystem.swift
//  DevelopumModule
//
//  ECS system for managing file indexing operations.
//  Creates index artifacts for fast file/text search.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation
import CryptoKit
import TelemetryCore

/// System that manages file indexing operations.
public actor DevelopumIndexSystem: System {
    public nonisolated var name: String { "DevelopumIndexSystem" }
    
    private let databaseService: DevelopumDatabaseService
    private let telemetryClient: TelemetryClient?
    
    /// Maximum concurrent indexing jobs.
    private let maxConcurrentJobs: Int = 3
    
    /// Current indexing jobs (tracked to enforce concurrency limit).
    private var activeJobs: Set<String> = []
    
    public init(
        databaseService: DevelopumDatabaseService,
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.telemetryClient = telemetryClient
    }
    
    public func update(world: World) async {
        await processIndexJobs(world: world)
        await cleanupStaleIndexes(world: world)
    }
    
    // MARK: - Index Job Processing
    
    /// Process pending index jobs.
    private func processIndexJobs(world: World) async {
        let indexJobs = await world.query(IndexJobComponent.self, RepoSessionComponent.self, OpenFileComponent.self)
        
        for (entity, indexJob, repoSession, openFile) in indexJobs {
            guard indexJob.status == .pending else { continue }
            
            // Enforce concurrency limit
            if activeJobs.count >= maxConcurrentJobs {
                continue
            }
            
            guard !activeJobs.contains(indexJob.jobId) else { continue }
            
            logInfo("Starting index job for: \(indexJob.filePath)", category: "DevelopumIndexSystem")
            
            // Mark job as running
            var updatedJob = indexJob
            updatedJob.status = .running
            updatedJob.startedAt = Date()
            await world.addComponent(entity, updatedJob)
            activeJobs.insert(indexJob.jobId)
            
            // Process indexing asynchronously
            Task {
                await performIndexing(
                    world: world,
                    entity: entity,
                    indexJob: indexJob,
                    repoSession: repoSession,
                    openFile: openFile
                )
                
                // Remove from active jobs
                await removeActiveJob(indexJob.jobId)
            }
        }
    }
    
    /// Perform indexing for a file.
    private func performIndexing(
        world: World,
        entity: EntityId,
        indexJob: IndexJobComponent,
        repoSession: RepoSessionComponent,
        openFile: OpenFileComponent
    ) async {
        let startTime = Date()
        let filePath = openFile.filePath
        let fullPath = "\(repoSession.repoPath)/\(filePath)"
        
        do {
            // Read file content
            let fileURL = URL(fileURLWithPath: fullPath)
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Compute content hash
            let hash = SHA256.hash(data: content.data(using: .utf8)!)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            // Build index structure
            let indexContent = try buildIndexContent(
                content: content,
                filePath: filePath,
                languageId: openFile.languageId
            )
            
            // Create index artifact record
            let artifact = IndexArtifactRecord(
                repoId: repoSession.id,
                artifactHash: hashString,
                filePath: filePath,
                mimeType: detectMimeType(for: filePath),
                languageId: openFile.languageId,
                fileSize: Int64(content.utf8.count),
                fileModifiedAt: try FileManager.default.attributesOfItem(atPath: fullPath)[.modificationDate] as? Date ?? Date(),
                indexedAt: Date(),
                indexContent: indexContent,
                isCurrent: true
            )
            
            // Mark previous indexes as stale
            try? await databaseService.markIndexArtifactsStale(repoId: repoSession.id, filePath: filePath)
            
            // Save new index
            try await databaseService.saveIndexArtifact(artifact)
            
            // Mark job as completed
            var completedJob = indexJob
            completedJob.status = .completed
            completedJob.completedAt = Date()
            completedJob.durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            await world.addComponent(entity, completedJob)
            
            logInfo("Indexing completed for: \(filePath) (\(completedJob.durationMs!)ms)", category: "DevelopumIndexSystem")
            
            if let telemetryClient {
                await telemetryClient.trackEvent(
                    name: "developum.index.completed",
                    properties: [
                        "filePath": filePath,
                        "durationMs": "\(completedJob.durationMs!)",
                        "languageId": openFile.languageId
                    ]
                )
            }
        } catch {
            // Mark job as failed
            var failedJob = indexJob
            failedJob.status = .failed
            failedJob.completedAt = Date()
            failedJob.durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            failedJob.errorMessage = error.localizedDescription
            await world.addComponent(entity, failedJob)
            
            logError("Indexing failed for: \(filePath) - \(error)", category: "DevelopumIndexSystem")
            
            if let telemetryClient {
                await telemetryClient.trackEvent(
                    name: "developum.index.failed",
                    properties: [
                        "filePath": filePath,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }
    
    // MARK: - Index Content Building
    
    /// Build index content structure for a file.
    private func buildIndexContent(
        content: String,
        filePath: String,
        languageId: String
    ) throws -> Data {
        let lines = content.components(separatedBy: .newlines)
        
        var indexData: [String: Any] = [:]
        indexData["version"] = "1.0"
        indexData["filePath"] = filePath
        indexData["languageId"] = languageId
        indexData["lineCount"] = lines.count
        indexData["indexedAt"] = ISO8601DateFormatter().string(from: Date())
        
        // Tokenize content for fast text search
        var tokens: [String] = []
        for (lineIndex, line) in lines.enumerated() {
            // Add line number and text
            let lineEntry: [String: Any] = [
                "lineNumber": lineIndex + 1,
                "text": line,
                "length": line.utf8.count
            ]
            
            // Extract identifiers (simple heuristic)
            let identifiers = extractIdentifiers(from: line, languageId: languageId)
            
            var lineData = lineEntry
            if !identifiers.isEmpty {
                lineData["identifiers"] = identifiers
            }
            
            tokens.append(contentsOf: identifiers)
        }
        
        indexData["tokens"] = Array(Set(tokens))  // Deduplicate
        indexData["lines"] = lines.enumerated().map { index, line in
            [
                "lineNumber": index + 1,
                "text": line,
                "length": line.utf8.count
            ]
        }
        
        return try JSONSerialization.data(withJSONObject: indexData, options: [.sortedKeys])
    }
    
    /// Extract identifiers from a line based on language.
    private func extractIdentifiers(from line: String, languageId: String) -> [String] {
        var identifiers: [String] = []
        
        // Simple regex-based extraction
        // TODO: Integrate with CapsuleCore for proper tokenization
        // STUB_TRACK: developum-tokenization – Real tokenization not integrated with CapsuleCore
        print("⚠️  STUB INVOKED: DevelopumIndexSystem.extractIdentifiers()")
        print("   Using simple regex-based identifier extraction - not integrated with CapsuleCore")
        let pattern = "[a-zA-Z_][a-zA-Z0-9_]*"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
        
        for match in matches {
            if let range = Swift.Range<String.Index>(match.range, in: line) {
                let identifier = String(line[range])
                
                // Filter out keywords
                if !isKeyword(identifier, languageId: languageId) && identifier.count >= 3 {
                    identifiers.append(identifier)
                }
            }
        }
        
        return identifiers
    }
    
    /// Check if identifier is a language keyword.
    private func isKeyword(_ identifier: String, languageId: String) -> Bool {
        let keywords: Set<String>
        
        switch languageId {
        case "swift":
            keywords = [
                "func", "var", "let", "struct", "class", "enum", "protocol",
                "import", "return", "if", "else", "for", "while", "switch",
                "case", "default", "break", "continue", "private", "public",
                "internal", "fileprivate", "open", "override", "static", "final"
            ]
        case "typescript", "javascript":
            keywords = [
                "function", "var", "let", "const", "class", "interface",
                "return", "if", "else", "for", "while", "switch", "case",
                "default", "break", "continue", "private", "public", "export",
                "import", "from", "async", "await"
            ]
        case "python":
            keywords = [
                "def", "class", "return", "if", "else", "elif", "for", "while",
                "import", "from", "as", "try", "except", "finally", "with",
                "lambda", "yield", "True", "False", "None"
            ]
        default:
            keywords = []
        }
        
        return keywords.contains(identifier)
    }
    
    // MARK: - Stale Index Cleanup
    
    /// Remove stale index artifacts.
    private func cleanupStaleIndexes(world: World) async {
        let sessions = await world.query(RepoSessionComponent.self)
        
        for (_, repoSession) in sessions {
            // Remove indexes older than 30 days that are marked as stale
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            do {
                try await databaseService.deleteStaleIndexArtifacts(olderThan: cutoffDate)
                logInfo("Cleaned up stale indexes for repo: \(repoSession.repoPath)", category: "DevelopumIndexSystem")
            } catch {
                logError("Failed to cleanup stale indexes: \(error)", category: "DevelopumIndexSystem")
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Remove job from active jobs set.
    private func removeActiveJob(_ jobId: String) async {
        activeJobs.remove(jobId)
    }
    
    /// Detect MIME type for a file path.
    private func detectMimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        
        let mimeTypes: [String: String] = [
            "swift": "text/x-swift",
            "js": "text/javascript",
            "ts": "text/typescript",
            "tsx": "text/typescript",
            "jsx": "text/javascript",
            "py": "text/x-python",
            "rs": "text/x-rust",
            "go": "text/x-go",
            "java": "text/x-java",
            "kt": "text/x-kotlin",
            "rb": "text/x-ruby",
            "php": "text/x-php",
            "c": "text/x-c",
            "cpp": "text/x-c++",
            "h": "text/x-c",
            "hpp": "text/x-c++",
            "m": "text/x-objc",
            "mm": "text/x-objc++",
            "sh": "text/x-shellscript",
            "json": "application/json",
            "yaml": "text/yaml",
            "yml": "text/yaml",
            "xml": "text/xml",
            "html": "text/html",
            "css": "text/css",
            "md": "text/markdown",
            "txt": "text/plain"
        ]
        
        return mimeTypes[ext] ?? "text/plain"
    }
}
