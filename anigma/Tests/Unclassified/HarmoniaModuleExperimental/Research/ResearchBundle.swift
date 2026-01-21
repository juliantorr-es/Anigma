//
//  ResearchBundle.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  First-class artifact representing scholarly research for a topic.
//  Papers & notes become dependencies that the bureaucracy can require.
//

import Foundation
import HarmoniaModule

// MARK: - Core Research Bundle

/// A bundle of scholarly research for a specific topic.
/// First-class artifact that can block or enable work.
public struct ResearchBundle: Sendable, Codable {
    /// Unique identifier for this research bundle.
    public let id: UUID

    /// Specification of what was researched.
    public let topicSpec: TopicSpec

    /// Papers found during research.
    public let papers: [PaperMetadata]

    /// Structured notes extracted from papers.
    public let extractedNotes: [ResearchNote]

    /// Links to doctrine domains and concepts.
    public let doctrineLinks: [DoctrineDomain: [String]]

    /// Provenance record of who/what created this.
    public let provenance: ProvenanceRecord

    /// Score (0.0-1.0) indicating research adequacy.
    public let adequacyScore: Double

    /// When this research was conducted.
    public let researchedAt: Date

    /// When this bundle expires (research becomes stale).
    public let expiresAt: Date

    /// Metadata about the research process.
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        topicSpec: TopicSpec,
        papers: [PaperMetadata],
        extractedNotes: [ResearchNote],
        doctrineLinks: [DoctrineDomain: [String]],
        provenance: ProvenanceRecord,
        adequacyScore: Double,
        researchedAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.topicSpec = topicSpec
        self.papers = papers
        self.extractedNotes = extractedNotes
        self.doctrineLinks = doctrineLinks
        self.provenance = provenance
        self.adequacyScore = adequacyScore
        self.researchedAt = researchedAt
        self.expiresAt = expiresAt ?? researchedAt.addingTimeInterval(90 * 24 * 60 * 60) // 90 days default
        self.metadata = metadata
    }

    /// Check if this research is still valid (not expired).
    public var isValid: Bool {
        return Date() < expiresAt
    }

    /// Check if research meets minimum adequacy threshold.
    public var isAdequate: Bool {
        return adequacyScore >= 0.7  // 70% threshold
    }
}

// MARK: - Topic Specification

/// Specification of what to research.
public struct TopicSpec: Sendable, Codable {
    /// Name of the module or feature being researched.
    public let moduleName: String

    /// Purpose/description of what's being built.
    public let purpose: String

    /// Scope boundaries for the research.
    public let scope: [String]

    /// Doctrine domains relevant to this topic.
    public let doctrineTags: [DoctrineDomain]

    /// Constraints or requirements.
    public let constraints: [String]

    /// Keywords for search queries.
    public let searchKeywords: [String]

    /// Maximum number of papers to fetch.
    public let maxPapers: Int

    /// Minimum publication year (for recency).
    public let minYear: Int?

    public init(
        moduleName: String,
        purpose: String,
        scope: [String] = [],
        doctrineTags: [DoctrineDomain] = [],
        constraints: [String] = [],
        searchKeywords: [String] = [],
        maxPapers: Int = 20,
        minYear: Int? = nil
    ) {
        self.moduleName = moduleName
        self.purpose = purpose
        self.scope = scope
        self.doctrineTags = doctrineTags
        self.constraints = constraints
        self.searchKeywords = searchKeywords
        self.maxPapers = maxPapers
        self.minYear = minYear
    }

    /// Generate search queries for scholarly APIs.
    public func generateQueries() -> [String] {
        var queries: [String] = []

        // Primary query: module name + purpose
        queries.append("\(moduleName) \(purpose)")

        // Doctrine-specific queries
        for tag in doctrineTags {
            queries.append("\(moduleName) \(tag.rawValue)")
            queries.append("\(purpose) \(tag.rawValue)")
        }

        // Keyword combinations
        for keyword in searchKeywords {
            queries.append("\(moduleName) \(keyword)")
            queries.append("\(purpose) \(keyword)")
        }

        return Array(Set(queries))  // Remove duplicates
    }
}

// MARK: - Paper Metadata

/// Metadata for a scholarly paper.
public struct PaperMetadata: Sendable, Codable {
    /// Unique identifier (DOI, arXiv ID, etc.)
    public let id: String

    /// Title of the paper.
    public let title: String

    /// List of authors.
    public let authors: [String]

    /// Publication year.
    public let year: Int

    /// Venue/conference/journal.
    public let venue: String?

    /// Abstract/summary.
    public let abstract: String?

    /// URL to paper (DOI link, arXiv link, etc.)
    public let url: URL?

    /// Citation count (if available).
    public let citationCount: Int?

    /// Whether paper is open access.
    public let isOpenAccess: Bool

    /// Source API (OpenAlex, arXiv, etc.)
    public let source: String

    /// When this metadata was fetched.
    public let fetchedAt: Date

    /// Relevance score (0.0-1.0) to the topic.
    public let relevanceScore: Double

    /// Tags/categories.
    public let tags: [String]

    public init(
        id: String,
        title: String,
        authors: [String],
        year: Int,
        venue: String? = nil,
        abstract: String? = nil,
        url: URL? = nil,
        citationCount: Int? = nil,
        isOpenAccess: Bool = false,
        source: String,
        fetchedAt: Date = Date(),
        relevanceScore: Double = 0.0,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.year = year
        self.venue = venue
        self.abstract = abstract
        self.url = url
        self.citationCount = citationCount
        self.isOpenAccess = isOpenAccess
        self.source = source
        self.fetchedAt = fetchedAt
        self.relevanceScore = relevanceScore
        self.tags = tags
    }

    /// Check if paper is recent (within last 5 years).
    public var isRecent: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear - year) <= 5
    }

    /// Check if paper is highly cited (> 100 citations).
    public var isHighlyCited: Bool {
        return citationCount ?? 0 > 100
    }

    /// Extract institution/lab from authors.
    public var primaryInstitution: String? {
        guard let firstAuthor = authors.first else { return nil }

        // Simple extraction: look for university patterns
        let institutionPatterns = [
            "University", "MIT", "Stanford", "Berkeley", "CMU", "ETH",
            "Microsoft", "Google", "Facebook", "Apple", "Amazon"
        ]

        for pattern in institutionPatterns {
            if firstAuthor.contains(pattern) {
                return pattern
            }
        }

        return nil
    }
}

// MARK: - Research Note

/// Structured note extracted from a paper.
public struct ResearchNote: Sendable, Codable {
    /// Unique identifier.
    public let id: UUID

    /// Paper this note is about.
    public let paperId: String

    /// Type of note (approach, finding, limitation, etc.)
    public let noteType: NoteType

    /// The note content.
    public let content: String

    /// Confidence in this extraction (0.0-1.0).
    public let confidence: Double

    /// When this note was extracted.
    public let extractedAt: Date

    /// Tags for categorization.
    public let tags: [String]

    public init(
        id: UUID = UUID(),
        paperId: String,
        noteType: NoteType,
        content: String,
        confidence: Double = 1.0,
        extractedAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.paperId = paperId
        self.noteType = noteType
        self.content = content
        self.confidence = confidence
        self.extractedAt = extractedAt
        self.tags = tags
    }

    /// Types of research notes.
    public enum NoteType: String, Sendable, Codable {
        case approach = "approach"          // Technical approach/method
        case finding = "finding"            // Key finding/result
        case limitation = "limitation"      // Limitation/caveat
        case futureWork = "future_work"     // Suggested future work
        case evaluation = "evaluation"      // Evaluation method/metric
        case security = "security"          // Security consideration
        case ethics = "ethics"              // Ethical consideration
        case implementation = "implementation" // Implementation detail
        case comparison = "comparison"      // Comparison to other work
    }
}

// MARK: - Provenance Record

/// Record of who/what created a research bundle.
public struct ProvenanceRecord: Sendable, Codable {
    /// Engine that conducted the research.
    public let engineId: String

    /// Engine type (DeepResearchEngine, etc.)
    public let engineType: String

    /// Capabilities used during research.
    public let capabilities: [String]

    /// When the research was conducted.
    public let conductedAt: Date

    /// Duration of research in seconds.
    public let duration: TimeInterval

    /// APIs/sources consulted.
    public let sourcesConsulted: [String]

    /// Hash of research process for audit.
    public let processHash: String

    public init(
        engineId: String,
        engineType: String,
        capabilities: [String],
        conductedAt: Date = Date(),
        duration: TimeInterval = 0.0,
        sourcesConsulted: [String] = [],
        processHash: String = ""
    ) {
        self.engineId = engineId
        self.engineType = engineType
        self.capabilities = capabilities
        self.conductedAt = conductedAt
        self.duration = duration
        self.sourcesConsulted = sourcesConsulted
        self.processHash = processHash
    }
}

// MARK: - Research Compliance

/// Compliance level for research sources.
public enum ResearchCompliance: String, Sendable, Codable {
    case metadataOnly = "metadata_only"     // Abstracts only, no full text
    case openAccess = "open_access"         // arXiv, OpenAlex full text OK
    case licensed = "licensed"              // Requires institutional access
    case prohibited = "prohibited"          // Paywalled, no scraping

    /// Check if a source is allowed for a given compliance level.
    public func allowsSource(_ source: String) -> Bool {
        switch self {
        case .metadataOnly:
            return true  // All sources allowed for metadata
        case .openAccess:
            return source.contains("arxiv") || source.contains("openalex")
        case .licensed:
            return source.contains("semanticscholar") || source.contains("crossref")
        case .prohibited:
            return false
        }
    }
}

// MARK: - Research Task

/// Task for conducting research.
public struct ResearchTask: Sendable, Codable {
    /// Unique identifier.
    public let id: UUID

    /// Topic to research.
    public let topicSpec: TopicSpec

    /// Project this research is for.
    public let projectId: UUID?

    /// Module this research is for.
    public let moduleId: UUID?

    /// Current status.
    public let status: TaskStatus

    /// Resulting research bundle (if completed).
    public let researchBundleId: UUID?

    /// Error message (if failed).
    public let errorMessage: String?

    /// When task was created.
    public let createdAt: Date

    /// When task started.
    public let startedAt: Date?

    /// When task completed.
    public let completedAt: Date?

    /// Priority level.
    public let priority: TaskPriority

    public init(
        id: UUID = UUID(),
        topicSpec: TopicSpec,
        projectId: UUID? = nil,
        moduleId: UUID? = nil,
        status: TaskStatus = .pending,
        researchBundleId: UUID? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.topicSpec = topicSpec
        self.projectId = projectId
        self.moduleId = moduleId
        self.status = status
        self.researchBundleId = researchBundleId
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.priority = priority
    }

    /// Task status.
    public enum TaskStatus: String, Sendable, Codable {
        case pending = "pending"
        case running = "running"
        case completed = "completed"
        case failed = "failed"
        case blocked = "blocked"
    }

    /// Task priority.
    public enum TaskPriority: String, Sendable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
}

// MARK: - Research Debt Task

/// Task created when research is inadequate.
public struct ResearchDebtTask: Sendable, Codable {
    /// Unique identifier.
    public let id: UUID

    /// Research bundle that was inadequate.
    public let researchBundleId: UUID

    /// Reason for debt (why research was inadequate).
    public let reason: String

    /// Required actions to resolve.
    public let requiredActions: [String]

    /// Blocked module/project.
    public let blockedEntityId: UUID

    /// Type of blocked entity.
    public let blockedEntityType: String

    /// When debt was created.
    public let createdAt: Date

    /// When debt was resolved.
    public let resolvedAt: Date?

    /// Priority for resolution.
    public let priority: ResearchTask.TaskPriority

    public init(
        id: UUID = UUID(),
        researchBundleId: UUID,
        reason: String,
        requiredActions: [String],
        blockedEntityId: UUID,
        blockedEntityType: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        priority: ResearchTask.TaskPriority = .medium
    ) {
        self.id = id
        self.researchBundleId = researchBundleId
        self.reason = reason
        self.requiredActions = requiredActions
        self.blockedEntityId = blockedEntityId
        self.blockedEntityType = blockedEntityType
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.priority = priority
    }
}

// MARK: - Helper Extensions

extension ResearchBundle {
    /// Generate a human-readable research dossier.
    public func generateDossier() -> String {
        var dossier = "# Research Dossier\n\n"
        dossier += "## Topic: \(topicSpec.moduleName)\n"
        dossier += "**Purpose**: \(topicSpec.purpose)\n\n"

        dossier += "## Research Summary\n"
        dossier += "- **Papers Found**: \(papers.count)\n"
        dossier += "- **Research Date**: \(researchedAt)\n"
        dossier += "- **Adequacy Score**: \(String(format: "%.1f", adequacyScore * 100))%\n"
        dossier += "- **Valid Until**: \(expiresAt)\n\n"

        dossier += "## Key Papers\n"
        for (index, paper) in papers.prefix(5).enumerated() {
            dossier += "\(index + 1). **\(paper.title)**\n"
            dossier += "   - Authors: \(paper.authors.joined(separator: ", "))\n"
            dossier += "   - Year: \(paper.year) \(paper.isRecent ? "(Recent)" : "")\n"
            if let venue = paper.venue {
                dossier += "   - Venue: \(venue)\n"
            }
            if let citations = paper.citationCount {
                dossier += "   - Citations: \(citations) \(paper.isHighlyCited ? "(Highly Cited)" : "")\n"
            }
            dossier += "   - Source: \(paper.source)\n\n"
        }

        dossier += "## Key Findings\n"
        let findings = extractedNotes.filter { $0.noteType == .finding }
        for finding in findings.prefix(10) {
            dossier += "- \(finding.content)\n"
        }

        dossier += "\n## Limitations & Caveats\n"
        let limitations = extractedNotes.filter { $0.noteType == .limitation }
        for limitation in limitations {
            dossier += "- \(limitation.content)\n"
        }

        dossier += "\n## Doctrine Links\n"
        for (domain, concepts) in doctrineLinks {
            dossier += "- **\(domain.rawValue)**: \(concepts.joined(separator: ", "))\n"
        }

        dossier += "\n## Why This Matters\n"
        dossier += "This research informs the design and implementation of \(topicSpec.moduleName) by:\n"
        for tag in topicSpec.doctrineTags {
            dossier += "- Providing \(tag.rawValue) context and constraints\n"
        }

        dossier += "\n## Uncertainties & Gaps\n"
        if adequacyScore < 0.7 {
            dossier += "- Research adequacy below threshold (needs improvement)\n"
        }
        if papers.count < 5 {
            dossier += "- Limited number of relevant papers found\n"
        }
        if !papers.contains(where: { $0.isRecent }) {
            dossier += "- No recent papers (last 5 years)\n"
        }

        dossier += "\n---\n"
        dossier += "*Generated by \(provenance.engineType) on \(provenance.conductedAt)*\n"

        return dossier
    }
}

extension PaperMetadata {
    /// Generate citation in APA format.
    public func generateCitation() -> String {
        let authorList = authors.count > 3 ?
            "\(authors[0]) et al." :
            authors.joined(separator: ", ")

        var citation = "\(authorList) (\(year)). \(title)."

        if let venue = venue {
            citation += " \(venue)."
        }

        if let url = url {
            citation += " \(url.absoluteString)"
        }

        return citation
    }
}
