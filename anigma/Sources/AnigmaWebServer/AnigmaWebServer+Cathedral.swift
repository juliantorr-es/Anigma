//
//  AnigmaWebServer+Cathedral.swift
//  AnigmaWebServer
//
//  Cathedral integration for Anigma web server
//  Provides evidence-driven ML operations through HTTP API
//

import Foundation
import Vapor
import CathedralModule
import ContextumModule
import DatabaseCore
import ContractsCore

// MARK: - Cathedral Web Server Integration

/// Anigma Web Server with Cathedral Evidence Enforcement
public actor CathedralWebServer {
    private let app: Application
    private let cathedral: CathedralFacade
    private let database: DatabaseActor

    public init(
        app: Application,
        cathedral: CathedralFacade,
        database: DatabaseActor
    ) {
        self.app = app
        self.cathedral = cathedral
        self.database = database
    }

    /// Configure routes with Cathedral enforcement
    public func configure() async throws {
        // Health check
        app.get("health") { _ in
            return HealthResponse(
                status: "healthy",
                cathedral: "operational",
                timestamp: Date()
            )
        }

        // ML Operations API
        let mlRoutes = app.grouped("api", "v1", "ml")

        // POST /api/v1/ml/embed - Generate embeddings
        mlRoutes.post("embed") { req async throws -> EmbedResponse in
            let request = try req.content.decode(EmbedRequest.self)
            return try await self.handleEmbedding(request: request, req: req)
        }

        // POST /api/v1/ml/search - Semantic search
        mlRoutes.post("search") { req async throws -> SearchResponse in
            let request = try req.content.decode(SearchRequest.self)
            return try await self.handleSearch(request: request, req: req)
        }

        // POST /api/v1/ml/generate - Text generation
        mlRoutes.post("generate") { req async throws -> GenerateResponse in
            let request = try req.content.decode(GenerateRequest.self)
            return try await self.handleGeneration(request: request, req: req)
        }

        // Evidence & Compliance API
        let evidenceRoutes = app.grouped("api", "v1", "evidence")

        // GET /api/v1/evidence/session/:sessionId - Get session evidence
        evidenceRoutes.get("session", ":sessionId") { req async throws -> SessionEvidenceResponse in
            guard let sessionId = req.parameters.get("sessionId") else {
                throw Abort(.badRequest, reason: "Missing session ID")
            }
            return try await self.handleGetSessionEvidence(sessionId: sessionId)
        }

        // GET /api/v1/evidence/compliance/:sessionId - Get compliance report
        evidenceRoutes.get("compliance", ":sessionId") { req async throws -> ComplianceReportResponse in
            guard let sessionId = req.parameters.get("sessionId") else {
                throw Abort(.badRequest, reason: "Missing session ID")
            }
            return try await self.handleGetComplianceReport(sessionId: sessionId)
        }

        // POST /api/v1/evidence/bundle - Export evidence bundle
        evidenceRoutes.post("bundle") { req async throws -> BundleExportResponse in
            let request = try req.content.decode(BundleExportRequest.self)
            return try await self.handleExportBundle(request: request)
        }

        // Document Tracking API
        let docsRoutes = app.grouped("api", "v1", "documents")

        // POST /api/v1/documents/acquire - Record document acquisition
        docsRoutes.post("acquire") { req async throws -> DocumentAcquireResponse in
            let request = try req.content.decode(DocumentAcquireRequest.self)
            return try await self.handleDocumentAcquisition(request: request)
        }

        // POST /api/v1/documents/transform - Record transformation
        docsRoutes.post("transform") { req async throws -> DocumentTransformResponse in
            let request = try req.content.decode(DocumentTransformRequest.self)
            return try await self.handleDocumentTransformation(request: request)
        }
    }

    // MARK: - ML Operation Handlers

    private func handleEmbedding(request: EmbedRequest, req: Request) async throws -> EmbedResponse {
        print("📝 API: Embedding request - model: \(request.model)")

        let operation = MLOperation(
            type: .embedding,
            sessionId: request.sessionId ?? UUID().uuidString,
            agentId: "web-api",
            parameters: [
                "text": request.text,
                "model": request.model
            ]
        )

        let result = try await cathedral.executeOperation(
            operation: operation,
            requirement: .moderate
        )

        return EmbedResponse(
            vector: result.data["vector"] ?? "",
            dimension: Int(result.data["dimension"] ?? "0") ?? 0,
            model: request.model,
            executionTimeMs: 0
        )
    }

    private func handleSearch(request: SearchRequest, req: Request) async throws -> SearchResponse {
        print("🔍 API: Search request - query: '\(request.query)'")

        let operation = MLOperation(
            type: .retrieval,
            sessionId: request.sessionId ?? UUID().uuidString,
            agentId: "web-api",
            parameters: [
                "query": request.query,
                "model": request.model,
                "topK": String(request.topK ?? 10),
                "threshold": String(request.threshold ?? 0.7)
            ]
        )

        let result = try await cathedral.executeOperation(
            operation: operation,
            requirement: .moderate
        )

        // Parse results
        var searchResults: [SearchResultItem] = []
        if let resultsJSON = result.data["results"],
           let data = resultsJSON.data(using: .utf8) {
            let decoder = JSONDecoder()
            let results = try? decoder.decode([SemanticSearchSystem.SearchResult].self, from: data)

            searchResults = results?.map { r in
                SearchResultItem(
                    documentId: r.chunkHash,
                    score: Double(r.similarity),
                    rank: 0
                )
            } ?? []
        }

        return SearchResponse(
            results: searchResults,
            query: request.query,
            model: request.model,
            executionTimeMs: 0
        )
    }

    private func handleGeneration(request: GenerateRequest, req: Request) async throws -> GenerateResponse {
        print("🤖 API: Generation request - prompt length: \(request.prompt.count)")

        let operation = MLOperation(
            type: .generation,
            sessionId: request.sessionId ?? UUID().uuidString,
            agentId: "web-api",
            parameters: [
                "prompt": request.prompt,
                "model": request.model,
                "maxTokens": String(request.maxTokens ?? 512)
            ]
        )

        let result = try await cathedral.executeOperation(
            operation: operation,
            requirement: .moderate
        )

        return GenerateResponse(
            generated: result.data["generated"] ?? "Generation not yet implemented",
            model: request.model,
            tokensGenerated: 0,
            executionTimeMs: 0
        )
    }

    // MARK: - Evidence Handlers

    private func handleGetSessionEvidence(sessionId: String) async throws -> SessionEvidenceResponse {
        print("📊 API: Get session evidence - session: \(sessionId)")

        let evidence = await cathedral.getSessionEvidence(sessionId: sessionId)

        return SessionEvidenceResponse(
            sessionId: sessionId,
            evidenceCount: evidence.count,
            evidence: evidence.map { e in
                EvidenceItem(
                    id: e.id,
                    type: e.type.rawValue,
                    timestamp: e.timestamp,
                    agentId: e.agentId
                )
            }
        )
    }

    private func handleGetComplianceReport(sessionId: String) async throws -> ComplianceReportResponse {
        print("📋 API: Get compliance report - session: \(sessionId)")

        let report = try await cathedral.getComplianceReport(sessionId: sessionId)

        return ComplianceReportResponse(
            sessionId: sessionId,
            chainValid: report.chainValid,
            complianceScore: report.complianceScore,
            isCompliant: report.isCompliant,
            violations: report.violations.map { v in
                ViolationItem(
                    id: v.id,
                    type: v.violationType.rawValue,
                    severity: v.severity.rawValue,
                    description: v.description,
                    detectedAt: v.detectedAt
                )
            }
        )
    }

    private func handleExportBundle(request: BundleExportRequest) async throws -> BundleExportResponse {
        print("📦 API: Export evidence bundle - session: \(request.sessionId)")

        let bundle = try await cathedral.exportEvidenceBundle(sessionId: request.sessionId)

        return BundleExportResponse(
            bundleId: bundle.bundleId,
            sessionId: request.sessionId,
            evidenceCount: bundle.evidenceCount,
            isCourtAdmissible: bundle.isCourtAdmissible,
            bundleHash: bundle.bundleHash,
            exportedAt: Date()
        )
    }

    // MARK: - Document Handlers

    private func handleDocumentAcquisition(request: DocumentAcquireRequest) async throws -> DocumentAcquireResponse {
        print("📄 API: Document acquisition - doc: \(request.documentId)")

        try await cathedral.recordDocumentAcquisition(
            documentId: request.documentId,
            filePath: request.filePath,
            sessionId: request.sessionId,
            agentId: "web-api",
            sourceMetadata: request.metadata ?? [:]
        )

        return DocumentAcquireResponse(
            documentId: request.documentId,
            recorded: true,
            timestamp: Date()
        )
    }

    private func handleDocumentTransformation(request: DocumentTransformRequest) async throws -> DocumentTransformResponse {
        print("🔄 API: Document transformation - doc: \(request.documentId)")

        let transformation = DocumentTransformation(
            id: UUID().uuidString,
            type: request.transformationType,
            toolName: request.toolName,
            toolVersion: request.toolVersion,
            timestamp: Date(),
            inputHash: request.inputHash,
            outputHash: request.outputHash,
            parameters: request.parameters ?? [:]
        )

        try await cathedral.recordDocumentTransformation(
            documentId: request.documentId,
            transformation: transformation,
            sessionId: request.sessionId,
            agentId: "web-api"
        )

        return DocumentTransformResponse(
            transformationId: transformation.id,
            recorded: true,
            timestamp: Date()
        )
    }
}

// MARK: - Request/Response Types

public struct EmbedRequest: Content {
    let text: String
    let model: String
    let sessionId: String?
}

public struct EmbedResponse: Content {
    let vector: String
    let dimension: Int
    let model: String
    let executionTimeMs: Int
}

public struct SearchRequest: Content {
    let query: String
    let model: String
    let topK: Int?
    let threshold: Double?
    let sessionId: String?
}

public struct SearchResponse: Content {
    let results: [SearchResultItem]
    let query: String
    let model: String
    let executionTimeMs: Int
}

public struct SearchResultItem: Content {
    let documentId: String
    let score: Double
    let rank: Int
}

public struct GenerateRequest: Content {
    let prompt: String
    let model: String
    let maxTokens: Int?
    let sessionId: String?
}

public struct GenerateResponse: Content {
    let generated: String
    let model: String
    let tokensGenerated: Int
    let executionTimeMs: Int
}

public struct SessionEvidenceResponse: Content {
    let sessionId: String
    let evidenceCount: Int
    let evidence: [EvidenceItem]
}

public struct EvidenceItem: Content {
    let id: String
    let type: String
    let timestamp: Date
    let agentId: String
}

public struct ComplianceReportResponse: Content {
    let sessionId: String
    let chainValid: Bool
    let complianceScore: Double
    let isCompliant: Bool
    let violations: [ViolationItem]
}

public struct ViolationItem: Content {
    let id: String
    let type: String
    let severity: String
    let description: String
    let detectedAt: Date
}

public struct BundleExportRequest: Content {
    let sessionId: String
    let reason: String?
}

public struct BundleExportResponse: Content {
    let bundleId: String
    let sessionId: String
    let evidenceCount: Int
    let isCourtAdmissible: Bool
    let bundleHash: String
    let exportedAt: Date
}

public struct DocumentAcquireRequest: Content {
    let documentId: String
    let filePath: String
    let sessionId: String
    let metadata: [String: String]?
}

public struct DocumentAcquireResponse: Content {
    let documentId: String
    let recorded: Bool
    let timestamp: Date
}

public struct DocumentTransformRequest: Content {
    let documentId: String
    let transformationType: String
    let toolName: String
    let toolVersion: String
    let inputHash: String
    let outputHash: String
    let sessionId: String
    let parameters: [String: String]?
}

public struct DocumentTransformResponse: Content {
    let transformationId: String
    let recorded: Bool
    let timestamp: Date
}

public struct HealthResponse: Content {
    let status: String
    let cathedral: String
    let timestamp: Date
}

// MARK: - Factory

extension CathedralWebServer {
    /// Create production web server with Cathedral
    public static func create(
        app: Application,
        embeddingComputing: EmbeddingComputing,
        modelRegistry: ModelRegistryProtocol,
        contextumDatabase: ContextumDatabase,
        cathedralDatabase: DatabaseActor
    ) async -> CathedralWebServer {

        // Create ML services
        let embeddingService = EmbeddingMLService(
            embeddingComputing: embeddingComputing,
            modelRegistry: modelRegistry
        )

        let retrievalService = RetrievalMLService(
            searchSystem: SemanticSearchSystem(),
            embeddingComputing: embeddingComputing,
            modelRegistry: modelRegistry,
            database: contextumDatabase
        )

        let router = MLServiceRouter(
            embeddingService: embeddingService,
            retrievalService: retrievalService,
            generationService: GenerationMLService(),
            classificationService: ClassificationMLService()
        )

        // Create Cathedral with ML services
        let cathedral = await CathedralModule.createFacade(
            database: cathedralDatabase,
            mlService: router
        )

        return CathedralWebServer(
            app: app,
            cathedral: cathedral,
            database: cathedralDatabase
        )
    }
}
