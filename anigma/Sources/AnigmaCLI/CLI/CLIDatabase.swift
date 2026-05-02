import Foundation
import DatabaseCore

/// CLI-specific database wrapper for conversations, runs, and indexed codebase
/// 
/// IMPORTANT: This is a composition root wrapper that creates DatabaseActor.
/// CLIs are approved composition roots per ADR-0018 and td-317bbb.
actor CLIDatabase {
    private let dbActor: DatabaseActor
    private let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
        self.dbActor = DatabaseActor(dbPath: dbPath)
    }

    /// Expose the underlying DatabaseActor as a DatabaseExecutor for feature modules
    public nonisolated var databaseExecutor: any DatabaseExecutor {
        dbActor
    }

    // MARK: - Schema Initialization

    func initialize() async throws {
        try await createConversationTables()
        try await createRunTables()
        try await createCodebaseIndexTables()
        try await createModelCacheTables()
        try await createMaturityTables()
    }

    private func createConversationTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            title TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            model_id TEXT,
            provider TEXT,
            workspace_path TEXT
        );

        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            token_count INTEGER,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS tool_calls (
            id TEXT PRIMARY KEY,
            message_id TEXT NOT NULL,
            tool_name TEXT NOT NULL,
            arguments TEXT NOT NULL,
            result TEXT,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
        CREATE INDEX IF NOT EXISTS idx_tool_calls_message ON tool_calls(message_id);
        CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);
        """

        try await dbActor.execute(sql: sql)
    }

    private func createRunTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS runs (
            id TEXT PRIMARY KEY,
            conversation_id TEXT,
            user_prompt TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            completed_at INTEGER,
            total_steps INTEGER DEFAULT 0,
            completed_steps INTEGER DEFAULT 0,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS run_steps (
            id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            step_number INTEGER NOT NULL,
            step_type TEXT NOT NULL,
            description TEXT,
            tool_calls TEXT,
            result TEXT,
            status TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            completed_at INTEGER,
            FOREIGN KEY (run_id) REFERENCES runs(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS run_artifacts (
            id TEXT PRIMARY KEY,
            run_id TEXT NOT NULL,
            artifact_type TEXT NOT NULL,
            file_path TEXT,
            content TEXT,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (run_id) REFERENCES runs(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_run_steps ON run_steps(run_id, step_number);
        CREATE INDEX IF NOT EXISTS idx_run_artifacts ON run_artifacts(run_id);
        CREATE INDEX IF NOT EXISTS idx_runs_status ON runs(status, started_at DESC);
        """

        try await dbActor.execute(sql: sql)
    }

    private func createCodebaseIndexTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS indexed_files (
            id TEXT PRIMARY KEY,
            file_path TEXT UNIQUE NOT NULL,
            language TEXT NOT NULL,
            purpose TEXT NOT NULL,
            line_count INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            last_modified INTEGER NOT NULL,
            indexed_at INTEGER NOT NULL,
            content_hash TEXT NOT NULL,
            description TEXT
        );

        CREATE TABLE IF NOT EXISTS symbols (
            id TEXT PRIMARY KEY,
            file_id TEXT NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            line_number INTEGER NOT NULL,
            column_number INTEGER,
            description TEXT,
            signature TEXT,
            FOREIGN KEY (file_id) REFERENCES indexed_files(id) ON DELETE CASCADE
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS files_fts USING fts5(
            file_path,
            description,
            content=indexed_files,
            content_rowid=rowid
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS symbols_fts USING fts5(
            name,
            description,
            signature,
            content=symbols,
            content_rowid=rowid
        );

        CREATE TABLE IF NOT EXISTS file_embeddings (
            file_id TEXT PRIMARY KEY,
            embedding BLOB NOT NULL,
            embedding_model TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (file_id) REFERENCES indexed_files(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS symbol_embeddings (
            symbol_id TEXT PRIMARY KEY,
            embedding BLOB NOT NULL,
            embedding_model TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (symbol_id) REFERENCES symbols(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_symbols_file ON symbols(file_id);
        CREATE INDEX IF NOT EXISTS idx_symbols_name ON symbols(name);
        CREATE INDEX IF NOT EXISTS idx_files_language ON indexed_files(language);
        """

        try await dbActor.execute(sql: sql)
    }

    private func createModelCacheTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS model_cache (
            cache_key TEXT PRIMARY KEY,
            prompt_hash TEXT NOT NULL,
            model_id TEXT NOT NULL,
            response TEXT NOT NULL,
            token_count INTEGER,
            created_at INTEGER NOT NULL,
            accessed_at INTEGER NOT NULL,
            access_count INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS local_models (
            model_id TEXT PRIMARY KEY,
            model_type TEXT NOT NULL,
            model_name TEXT NOT NULL,
            model_path TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            downloaded_at INTEGER NOT NULL,
            last_used INTEGER,
            config TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_cache_accessed ON model_cache(accessed_at DESC);
        CREATE INDEX IF NOT EXISTS idx_cache_prompt ON model_cache(prompt_hash);
        CREATE INDEX IF NOT EXISTS idx_models_type ON local_models(model_type);
        """

        try await dbActor.execute(sql: sql)
    }

    // MARK: - Conversation Operations

    func createConversation(title: String, modelId: String?, provider: String?) async throws -> String {
        let id = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO conversations (id, title, created_at, updated_at, model_id, provider)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [id, title, String(now), String(now), modelId ?? "", provider ?? ""]
        )

        return id
    }

    func addMessage(
        conversationId: String,
        role: String,
        content: String,
        tokenCount: Int?
    ) async throws -> String {
        let id = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO messages (id, conversation_id, role, content, created_at, token_count)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [
                id,
                conversationId,
                role,
                content,
                String(now),
                tokenCount.map(String.init) ?? ""
            ]
        )

        // Update conversation timestamp
        try await updateConversationTimestamp(conversationId)

        return id
    }

    private func updateConversationTimestamp(_ conversationId: String) async throws {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE conversations SET updated_at = ? WHERE id = ?"
        try await dbActor.execute(sql: sql, parameters: [String(now), conversationId])
    }

    // MARK: - Run Operations

    func createRun(conversationId: String?, userPrompt: String) async throws -> String {
        let id = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO runs (id, conversation_id, user_prompt, status, started_at)
        VALUES (?, ?, ?, 'running', ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [id, conversationId ?? "", userPrompt, String(now)]
        )

        return id
    }

    func updateRunStatus(_ runId: String, status: String) async throws {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE runs SET status = ?, completed_at = ? WHERE id = ?"
        try await dbActor.execute(sql: sql, parameters: [status, String(now), runId])
    }

    func addRunStep(
        runId: String,
        stepNumber: Int,
        stepType: String,
        description: String?
    ) async throws -> String {
        let id = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO run_steps (id, run_id, step_number, step_type, description, status, started_at)
        VALUES (?, ?, ?, ?, ?, 'running', ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [
                id,
                runId,
                String(stepNumber),
                stepType,
                description ?? "",
                String(now)
            ]
        )

        return id
    }

    // MARK: - Query Operations

    func getRecentConversations(limit: Int = 10) async throws -> [[String: Any]] {
        let sql = """
        SELECT id, title, created_at, updated_at, model_id, provider
        FROM conversations
        ORDER BY updated_at DESC
        LIMIT ?
        """

        return try await dbActor.query(sql: sql, parameters: [String(limit)])
    }

    func getConversationMessages(_ conversationId: String) async throws -> [[String: Any]] {
        let sql = """
        SELECT id, role, content, created_at, token_count
        FROM messages
        WHERE conversation_id = ?
        ORDER BY created_at ASC
        """

        return try await dbActor.query(sql: sql, parameters: [conversationId])
    }

    // MARK: - Maturity Assessment Tables

    private func createMaturityTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS maturity_assessments (
            id TEXT PRIMARY KEY,
            module TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            overall_maturity TEXT NOT NULL,
            target_maturity TEXT NOT NULL,
            summary TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS dimension_assessments (
            id TEXT PRIMARY KEY,
            assessment_id TEXT NOT NULL,
            dimension TEXT NOT NULL,
            score REAL NOT NULL,
            current_level TEXT NOT NULL,
            target_level TEXT NOT NULL,
            findings TEXT NOT NULL,
            FOREIGN KEY (assessment_id) REFERENCES maturity_assessments(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS improvements (
            id TEXT PRIMARY KEY,
            assessment_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dimension TEXT NOT NULL,
            impact TEXT NOT NULL,
            effort TEXT NOT NULL,
            priority INTEGER NOT NULL,
            suggested_changes TEXT NOT NULL,
            code_locations TEXT,
            dependencies TEXT,
            status TEXT NOT NULL DEFAULT 'suggested',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (assessment_id) REFERENCES maturity_assessments(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS build_warnings (
            id TEXT PRIMARY KEY,
            assessment_id TEXT NOT NULL,
            message TEXT NOT NULL,
            file TEXT,
            line INTEGER,
            suggested_fix TEXT,
            FOREIGN KEY (assessment_id) REFERENCES maturity_assessments(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS build_errors (
            id TEXT PRIMARY KEY,
            assessment_id TEXT NOT NULL,
            message TEXT NOT NULL,
            file TEXT,
            line INTEGER,
            suggested_fix TEXT,
            FOREIGN KEY (assessment_id) REFERENCES maturity_assessments(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_assessments_module ON maturity_assessments(module, timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_improvements_status ON improvements(status);
        CREATE INDEX IF NOT EXISTS idx_improvements_priority ON improvements(priority DESC);
        """

        try await dbActor.execute(sql: sql)
    }

    // MARK: - Maturity Assessment Operations

    func storeMaturityAssessment(_ assessment: MaturityAssessment) async throws {
        let assessmentId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)

        // Insert main assessment
        let assessmentSql = """
        INSERT INTO maturity_assessments (id, module, timestamp, overall_maturity, target_maturity, summary)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: assessmentSql,
            parameters: [
                assessmentId,
                assessment.module,
                String(Int(assessment.timestamp.timeIntervalSince1970)),
                assessment.overallMaturity.rawValue,
                assessment.targetMaturity.rawValue,
                assessment.summary
            ]
        )

        // Insert dimension assessments
        for dimension in assessment.dimensions {
            let dimensionId = UUID().uuidString
            let findingsJson = try JSONEncoder().encode(dimension.findings)

            let dimensionSql = """
            INSERT INTO dimension_assessments (id, assessment_id, dimension, score, current_level, target_level, findings)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """

            try await dbActor.execute(
                sql: dimensionSql,
                parameters: [
                    dimensionId,
                    assessmentId,
                    dimension.dimension.rawValue,
                    String(dimension.score),
                    dimension.currentLevel.rawValue,
                    dimension.targetLevel.rawValue,
                    String(data: findingsJson, encoding: .utf8) ?? "[]"
                ]
            )
        }

        // Insert improvements
        for improvement in assessment.improvements {
            try await storeImprovement(improvement, assessmentId: assessmentId)
        }

        // Insert build warnings
        for warning in assessment.buildWarnings {
            try await storeBuildWarning(warning, assessmentId: assessmentId)
        }

        // Insert build errors
        for error in assessment.buildErrors {
            try await storeBuildError(error, assessmentId: assessmentId)
        }
    }

    private func storeImprovement(_ improvement: Improvement, assessmentId: String) async throws {
        let now = Int(Date().timeIntervalSince1970)
        let changesJson = try JSONEncoder().encode(improvement.suggestedChanges)
        let locationsJson = try JSONEncoder().encode(improvement.codeLocations)
        let depsJson = try JSONEncoder().encode(improvement.dependencies)

        let sql = """
        INSERT INTO improvements (
            id, assessment_id, title, description, dimension, impact, effort, priority,
            suggested_changes, code_locations, dependencies, status, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [
                improvement.id.uuidString,
                assessmentId,
                improvement.title,
                improvement.description,
                improvement.dimension.rawValue,
                improvement.impact.rawValue,
                improvement.effort.rawValue,
                String(improvement.priority),
                String(data: changesJson, encoding: .utf8) ?? "[]",
                String(data: locationsJson, encoding: .utf8) ?? "[]",
                String(data: depsJson, encoding: .utf8) ?? "[]",
                improvement.status.rawValue,
                String(now),
                String(now)
            ]
        )
    }

    private func storeBuildWarning(_ warning: BuildWarning, assessmentId: String) async throws {
        let id = UUID().uuidString
        let sql = """
        INSERT INTO build_warnings (id, assessment_id, message, file, line, suggested_fix)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [
                id,
                assessmentId,
                warning.message,
                warning.file ?? "",
                warning.line.map(String.init) ?? "",
                warning.suggestedFix ?? ""
            ]
        )
    }

    private func storeBuildError(_ error: BuildError, assessmentId: String) async throws {
        let id = UUID().uuidString
        let sql = """
        INSERT INTO build_errors (id, assessment_id, message, file, line, suggested_fix)
        VALUES (?, ?, ?, ?, ?, ?)
        """

        try await dbActor.execute(
            sql: sql,
            parameters: [
                id,
                assessmentId,
                error.message,
                error.file ?? "",
                error.line.map(String.init) ?? "",
                error.suggestedFix ?? ""
            ]
        )
    }

    func updateImprovementStatus(_ improvementId: UUID, status: ImprovementStatus) async throws {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE improvements SET status = ?, updated_at = ? WHERE id = ?"
        try await dbActor.execute(
            sql: sql,
            parameters: [status.rawValue, String(now), improvementId.uuidString]
        )
    }

    func getLatestAssessments(limit: Int = 10) async throws -> [[String: Any]] {
        let sql = """
        SELECT id, module, timestamp, overall_maturity, target_maturity, summary
        FROM maturity_assessments
        ORDER BY timestamp DESC
        LIMIT ?
        """

        return try await dbActor.query(sql: sql, parameters: [String(limit)])
    }

    func getImprovementsByStatus(_ status: ImprovementStatus) async throws -> [[String: Any]] {
        let sql = """
        SELECT id, title, description, dimension, impact, effort, priority, status
        FROM improvements
        WHERE status = ?
        ORDER BY priority DESC
        """

        return try await dbActor.query(sql: sql, parameters: [status.rawValue])
    }
}
