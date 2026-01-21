import Foundation
import ArgumentParser
import AnigmaCLIRAG

@available(macOS 13.0, *)
struct RAGCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rag",
        abstract: "Manage RAG (Retrieval-Augmented Generation) pipeline",
        subcommands: [IndexRAG.self, SearchRAG.self, StatsRAG.self]
    )
}

@available(macOS 13.0, *)
struct IndexRAG: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Index codebase for RAG retrieval"
    )

    @Option(name: .long, help: "Path to index")
    var path: String = "."

    @Option(name: .long, help: "Database path")
    var db: String = ".anigma/rag.db"

    @Option(name: .long, help: "Chunk size")
    var chunkSize: Int = 512

    @Option(name: .long, help: "Overlap size")
    var overlap: Int = 128

    @Flag(name: .long, help: "Enable verbose output")
    var verbose: Bool = false

    func run() async throws {
        print("🔍 Indexing codebase for RAG...")
        print("   Path: \(path)")
        print("   Database: \(db)")
        print("   Chunk size: \(chunkSize), Overlap: \(overlap)")
        print()

        // Initialize RAG pipeline
        let rag = RAGPipeline(dbPath: db, chunkSize: chunkSize, overlapSize: overlap)
        try await rag.initialize()

        // Scan files
        let fm = FileManager.default
        let enumerator = fm.enumerator(atPath: path)

        var fileCount = 0
        var chunkCount = 0

        while let file = enumerator?.nextObject() as? String {
            let fullPath = URL(fileURLWithPath: path).appendingPathComponent(file).path

            // Skip non-code files
            guard isCodeFile(file) else { continue }

            // Read file
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
                continue
            }

            let language = detectLanguage(file)

            if verbose {
                print("📄 \(file) (\(language))")
            }

            // Chunk and index
            let chunks = try await rag.chunkFile(path: file, content: content, language: language)
            try await rag.indexChunks(chunks)

            fileCount += 1
            chunkCount += chunks.count

            if !verbose && fileCount % 10 == 0 {
                print("   Indexed \(fileCount) files, \(chunkCount) chunks...")
            }
        }

        print()
        print("✅ Indexing complete!")
        print("   Files: \(fileCount)")
        print("   Chunks: \(chunkCount)")
    }

    private func isCodeFile(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ["swift", "py", "js", "ts", "go", "rs", "java", "c", "cpp", "h", "hpp"].contains(ext)
    }

    private func detectLanguage(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "go": return "Go"
        case "rs": return "Rust"
        case "java": return "Java"
        case "c", "h": return "C"
        case "cpp", "hpp": return "C++"
        default: return "Unknown"
        }
    }
}

@available(macOS 13.0, *)
struct SearchRAG: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search indexed codebase"
    )

    @Argument(help: "Search query")
    var query: String

    @Option(name: .long, help: "Database path")
    var db: String = ".anigma/rag.db"

    @Option(name: .long, help: "Number of results")
    var limit: Int = 5

    @Flag(name: .long, help: "Use vector search")
    var vector: Bool = false

    func run() async throws {
        let rag = RAGPipeline(dbPath: db)
        try await rag.initialize()

        print("🔍 Searching for: \"\(query)\"")
        print()

        let results = try await rag.search(query: query, limit: limit, useVector: vector)

        if results.isEmpty {
            print("No results found.")
            return
        }

        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result.filePath):\(result.startLine)-\(result.endLine)")
            print("    Score: \(String(format: "%.2f", result.score)) | Type: \(result.chunkType) | Source: \(result.source)")
            print()

            // Show snippet
            let lines = result.content.components(separatedBy: CharacterSet.newlines)
            for (i, line) in lines.prefix(5).enumerated() {
                print(String(format: "    %4d | %@", result.startLine + i, line))
            }
            if lines.count > 5 {
                print("    ...")
            }
            print()
        }
    }
}

@available(macOS 13.0, *)
struct StatsRAG: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show RAG index statistics"
    )

    @Option(name: .long, help: "Database path")
    var db: String = ".anigma/rag.db"

    func run() async throws {
        print("📊 RAG Index Statistics")
        print("   Database: \(db)")
        print()

        var dbHandle: OpaquePointer?
        guard sqlite3_open(db, &dbHandle) == SQLITE_OK, let db = dbHandle else {
            print("   Failed to open database")
            return
        }
        defer { sqlite3_close(db) }

        // Total chunks
        var totalChunks: Int64 = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM code_chunks", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalChunks = sqlite3_column_int64(stmt, 0)
            }
            sqlite3_finalize(stmt)
        }

        // Indexed files (distinct file paths)
        var indexedFiles: Int64 = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(DISTINCT file_path) FROM code_chunks", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                indexedFiles = sqlite3_column_int64(stmt, 0)
            }
            sqlite3_finalize(stmt)
        }

        // Languages distribution
        var languages: [String: Int64] = [:]
        if sqlite3_prepare_v2(db, "SELECT language, COUNT(*) FROM code_chunks GROUP BY language", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let lang = String(cString: sqlite3_column_text(stmt, 0))
                let count = sqlite3_column_int64(stmt, 1)
                languages[lang] = count
            }
            sqlite3_finalize(stmt)
        }

        // Index size (file size)
        let fileManager = FileManager.default
        var indexSize: UInt64 = 0
        if fileManager.fileExists(atPath: db) {
            let attrs = try? fileManager.attributesOfItem(atPath: db)
            indexSize = attrs?[.size] as? UInt64 ?? 0
        }

        print("   Total chunks: \(totalChunks)")
        print("   Indexed files: \(indexedFiles)")
        print("   Languages:")
        for (lang, count) in languages.sorted(by: { $0.value > $1.value }) {
            print("     - \(lang): \(count)")
        }
        if languages.isEmpty {
            print("     - No language data")
        }
        print("   Index size: \(ByteCountFormatter.string(fromByteCount: Int64(indexSize), countStyle: .file))")
    }
}
