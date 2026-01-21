//
//  ResearchClient.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Boring, deterministic clients for scholarly APIs.
//  Not "LLM goes internet shopping" - just API calls with capability checks.
//

import Foundation
import HarmoniaModule

// MARK: - Research Client Configuration

/// Configuration for research clients.
public struct ResearchClientConfig: Sendable, Codable {
    /// OpenAlex API configuration.
    public let openAlexConfig: OpenAlexConfig?

    /// arXiv API configuration.
    public let arxivConfig: ArxivConfig?

    /// Rate limiting between requests.
    public let rateLimitDelay: TimeInterval

    /// Maximum retries for failed requests.
    public let maxRetries: Int

    /// Request timeout.
    public let timeout: TimeInterval

    /// Compliance level for research sources.
    public let complianceLevel: ResearchCompliance

    /// Maximum papers to fetch per query.
    public let maxPapersPerQuery: Int

    public init(
        openAlexConfig: OpenAlexConfig? = nil,
        arxivConfig: ArxivConfig? = nil,
        rateLimitDelay: TimeInterval = 2.0,  // Scholarly APIs are more sensitive
        maxRetries: Int = 3,
        timeout: TimeInterval = 60.0,  // Scholarly APIs can be slower
        complianceLevel: ResearchCompliance = .openAccess,
        maxPapersPerQuery: Int = 50
    ) {
        self.openAlexConfig = openAlexConfig
        self.arxivConfig = arxivConfig
        self.rateLimitDelay = rateLimitDelay
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.complianceLevel = complianceLevel
        self.maxPapersPerQuery = maxPapersPerQuery
    }
}

/// OpenAlex API configuration.
public struct OpenAlexConfig: Sendable, Codable {
    /// Base URL for OpenAlex API.
    public let baseURL: URL

    /// Optional API key for higher rate limits.
    public let apiKey: String?

    /// Email for polite usage tracking.
    public let email: String?

    public init(
        baseURL: URL = URL(string: "https://api.openalex.org")!,
        apiKey: String? = nil,
        email: String? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.email = email
    }
}

/// arXiv API configuration.
public struct ArxivConfig: Sendable, Codable {
    /// Base URL for arXiv API.
    public let baseURL: URL

    /// User agent for polite usage.
    public let userAgent: String

    /// Email for polite usage tracking.
    public let email: String?

    public init(
        baseURL: URL = URL(string: "https://export.arxiv.org/api/query")!,
        userAgent: String = "Anigma/1.0 (https://github.com/anigma-ai/anigma)",
        email: String? = nil
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.email = email
    }
}

// MARK: - Research Client Errors

/// Errors for research client operations.
public enum ResearchClientError: Error, Sendable {
    case networkError(Error)
    case httpError(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse
    case authenticationRequired
    case timeout
    case invalidURL
    case complianceViolation(source: String, required: ResearchCompliance)
    case sourceNotConfigured(String)
    case queryTooBroad
    case noResultsFound
    case parsingError(String)
}

// MARK: - Base Research Client Protocol

/// Base protocol for research clients.
public protocol ResearchClient: Sendable {
    var config: ResearchClientConfig { get }

    /// Search for papers by query.
    func searchPapers(query: String, limit: Int, minYear: Int?) async throws -> [PaperMetadata]

    /// Fetch paper details by ID.
    func fetchPaper(id: String) async throws -> PaperMetadata

    /// Check if a source is allowed under current compliance.
    func isSourceAllowed(_ source: String) -> Bool
}

// MARK: - Default Research Client Implementation

/// Default implementation of ResearchClient.
public actor DefaultResearchClient: ResearchClient {
    public let config: ResearchClientConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let xmlParser: XMLParser

    private var lastRequestTime: Date = .distantPast
    private let rateLimitQueue = DispatchQueue(label: "com.anigma.researchclient.ratelimit")

    public init(config: ResearchClientConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "Anigma/1.0 (https://github.com/anigma-ai/anigma)"
        ]

        self.session = URLSession(configuration: sessionConfig)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.xmlParser = XMLParser()
    }

    public func isSourceAllowed(_ source: String) -> Bool {
        return config.complianceLevel.allowsSource(source)
    }

    private func enforceRateLimit() async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)

        if timeSinceLastRequest < config.rateLimitDelay {
            let delay = config.rateLimitDelay - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        lastRequestTime = Date()
    }

    private func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Respect rate limiting
        try await enforceRateLimit()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResearchClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401, 403:
            throw ResearchClientError.authenticationRequired
        case 429:
            let retryAfter = extractRetryAfter(from: httpResponse)
            throw ResearchClientError.rateLimited(retryAfter: retryAfter)
        case 408, 504:
            throw ResearchClientError.timeout
        default:
            throw ResearchClientError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func fetchWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T {
        var lastError: Error?

        for attempt in 0..<config.maxRetries {
            do {
                return try await fetch(request)
            } catch ResearchClientError.rateLimited(let retryAfter) {
                let delay = retryAfter ?? Double(attempt + 1) * 2.0
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                lastError = error
                continue
            } catch ResearchClientError.timeout {
                if attempt < config.maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(Double(attempt + 1) * 1_000_000_000))
                    lastError = error
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }

        throw lastError ?? ResearchClientError.networkError(NSError(domain: "ResearchClient", code: -1, userInfo: nil))
    }

    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let retryAfterString = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        if let seconds = Int(retryAfterString) {
            return TimeInterval(seconds)
        }

        // Try to parse as HTTP date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        if let date = formatter.date(from: retryAfterString) {
            return date.timeIntervalSince(Date())
        }

        return nil
    }

    // MARK: - Paper Search Implementation

    public func searchPapers(query: String, limit: Int, minYear: Int?) async throws -> [PaperMetadata] {
        var allPapers: [PaperMetadata] = []

        // Try OpenAlex first if configured
        if let openAlexConfig = config.openAlexConfig, isSourceAllowed("openalex") {
            do {
                let openAlexPapers = try await searchOpenAlex(
                    query: query,
                    limit: limit,
                    minYear: minYear,
                    config: openAlexConfig
                )
                allPapers.append(contentsOf: openAlexPapers)
            } catch {
                print("OpenAlex search failed: \(error)")
            }
        }

        // Try arXiv if configured
        if let arxivConfig = config.arxivConfig, isSourceAllowed("arxiv") {
            do {
                let arxivPapers = try await searchArxiv(
                    query: query,
                    limit: limit - allPapers.count,
                    minYear: minYear,
                    config: arxivConfig
                )
                allPapers.append(contentsOf: arxivPapers)
            } catch {
                print("arXiv search failed: \(error)")
            }
        }

        // Sort by relevance (citation count, recency)
        allPapers.sort { paper1, paper2 in
            let score1 = relevanceScore(for: paper1)
            let score2 = relevanceScore(for: paper2)
            return score1 > score2
        }

        return Array(allPapers.prefix(limit))
    }

    public func fetchPaper(id: String) async throws -> PaperMetadata {
        // Determine source from ID format
        if id.hasPrefix("https://doi.org/") || id.contains("openalex.org") {
            guard let openAlexConfig = config.openAlexConfig else {
                throw ResearchClientError.sourceNotConfigured("OpenAlex")
            }
            return try await fetchOpenAlexPaper(id: id, config: openAlexConfig)
        } else if id.hasPrefix("arXiv:") || id.contains("arxiv.org") {
            guard let arxivConfig = config.arxivConfig else {
                throw ResearchClientError.sourceNotConfigured("arXiv")
            }
            return try await fetchArxivPaper(id: id, config: arxivConfig)
        } else {
            throw ResearchClientError.parsingError("Unknown paper ID format: \(id)")
        }
    }

    // MARK: - Relevance Scoring

    private func relevanceScore(for paper: PaperMetadata) -> Double {
        var score = 0.0

        // Citation impact
        if let citations = paper.citationCount {
            if citations > 1000 {
                score += 3.0
            } else if citations > 100 {
                score += 2.0
            } else if citations > 10 {
                score += 1.0
            }
        }

        // Recency
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - paper.year
        if age <= 1 {
            score += 3.0
        } else if age <= 3 {
            score += 2.0
        } else if age <= 5 {
            score += 1.0
        }

        // Venue prestige (simple heuristic)
        if let venue = paper.venue?.lowercased() {
            if venue.contains("neurips") || venue.contains("icml") || venue.contains("iclr") {
                score += 2.0
            } else if venue.contains("acl") || venue.contains("emnlp") || venue.contains("naacl") {
                score += 1.5
            } else if venue.contains("cvpr") || venue.contains("iccv") || venue.contains("eccv") {
                score += 1.5
            } else if venue.contains("www") || venue.contains("kdd") || venue.contains("sigir") {
                score += 1.0
            }
        }

        return score
    }
}

// MARK: - OpenAlex Client

extension DefaultResearchClient {
    /// Search OpenAlex for papers.
    private func searchOpenAlex(
        query: String,
        limit: Int,
        minYear: Int?,
        config: OpenAlexConfig
    ) async throws -> [PaperMetadata] {
        let url = config.baseURL.appendingPathComponent("works")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }

        var queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "per_page", value: "\(min(limit, 200))"),
            URLQueryItem(name: "sort", value: "cited_by_count:desc")
        ]

        if let minYear = minYear {
            queryItems.append(URLQueryItem(name: "filter", value: "publication_year:>=\(minYear)"))
        }

        if let email = config.email {
            queryItems.append(URLQueryItem(name: "mailto", value: email))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey = config.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        struct OpenAlexResponse: Decodable {
            let results: [OpenAlexWork]
        }

        struct OpenAlexWork: Decodable {
            let id: String
            let doi: String?
            let title: String
            let displayName: String
            let publicationYear: Int
            let authorships: [OpenAlexAuthorship]?
            let hostVenue: OpenAlexVenue?
            let abstract: String?
            let citedByCount: Int?
            let isOa: Bool?
            let primaryTopic: OpenAlexTopic?

            struct OpenAlexAuthorship: Decodable {
                let author: OpenAlexAuthor

                struct OpenAlexAuthor: Decodable {
                    let displayName: String
                }
            }

            struct OpenAlexVenue: Decodable {
                let displayName: String?
                let issn: String?
            }

            struct OpenAlexTopic: Decodable {
                let displayName: String?
            }
        }

        let response: OpenAlexResponse = try await fetchWithRetry(request)

        return response.results.prefix(limit).map { work in
            let authors = work.authorships?.map { $0.author.displayName } ?? []
            let venue = work.hostVenue?.displayName
            let abstract = work.abstract

            let paperId = work.doi ?? work.id.replacingOccurrences(of: "https://openalex.org/", with: "")

            return PaperMetadata(
                id: paperId,
                title: work.displayName,
                authors: authors,
                year: work.publicationYear,
                venue: venue,
                abstract: abstract,
                url: URL(string: work.doi ?? work.id),
                citationCount: work.citedByCount,
                isOpenAccess: work.isOa ?? false,
                source: "openalex",
                relevanceScore: 0.0,  // Will be calculated later
                tags: work.primaryTopic?.displayName.map { [$0] } ?? []
            )
        }
    }

    /// Fetch a specific paper from OpenAlex.
    private func fetchOpenAlexPaper(id: String, config: OpenAlexConfig) async throws -> PaperMetadata {
        let paperId = id.replacingOccurrences(of: "https://doi.org/", with: "")
            .replacingOccurrences(of: "https://openalex.org/", with: "")

        let url = config.baseURL.appendingPathComponent("works").appendingPathComponent(paperId)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }

        if let email = config.email {
            components.queryItems = [URLQueryItem(name: "mailto", value: email)]
        }

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey = config.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        let work: OpenAlexWork = try await fetchWithRetry(request)

        let authors = work.authorships?.map { $0.author.displayName } ?? []
        let venue = work.hostVenue?.displayName
        let abstract = work.abstract

        return PaperMetadata(
            id: work.doi ?? work.id.replacingOccurrences(of: "https://openalex.org/", with: ""),
            title: work.displayName,
            authors: authors,
            year: work.publicationYear,
            venue: venue,
            abstract: abstract,
            url: URL(string: work.doi ?? work.id),
            citationCount: work.citedByCount,
            isOpenAccess: work.isOa ?? false,
            source: "openalex",
            relevanceScore: 0.0,
            tags: work.primaryTopic?.displayName.map { [$0] } ?? []
        )
    }
}

// MARK: - arXiv Client

extension DefaultResearchClient {
    /// Search arXiv for papers.
    private func searchArxiv(
        query: String,
        limit: Int,
        minYear: Int?,
        config: ArxivConfig
    ) async throws -> [PaperMetadata] {
        guard let components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }

        var queryItems = [
            URLQueryItem(name: "search_query", value: "all:\(query)"),
            URLQueryItem(name: "max_results", value: "\(min(limit, 100))"),
            URLQueryItem(name: "sortBy", value: "relevance"),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]

        if let email = config.email {
            queryItems.append(URLQueryItem(name: "email", value: email))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)

        // Parse Atom XML response
        let parser = ArxivAtomParser()
        let entries = try parser.parse(data: data)

        return entries.prefix(limit).map { entry in
            let year = Calendar.current.component(.year, from: entry.published)

            return PaperMetadata(
                id: entry.id,
                title: entry.title,
                authors: entry.authors,
                year: year,
                venue: "arXiv",
                abstract: entry.summary,
                url: URL(string: entry.id),
                citationCount: nil,  // arXiv doesn't provide citation counts
                isOpenAccess: true,  // arXiv is open access
                source: "arxiv",
                relevanceScore: 0.0,
                tags: entry.categories
            )
        }
    }

    /// Fetch a specific paper from arXiv.
    private func fetchArxivPaper(id: String, config: ArxivConfig) async throws -> PaperMetadata {
        let arxivId = id.replacingOccurrences(of: "arXiv:", with: "")
            .replacingOccurrences(of: "https://arxiv.org/abs/", with: "")
            .replacingOccurrences(of: "https://arxiv.org/pdf/", with: "")
            .replacingOccurrences(of: ".pdf", with: "")

        guard let components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }

        var queryItems = [
            URLQueryItem(name: "id_list", value: arxivId)
        ]

        if let email = config.email {
            queryItems.append(URLQueryItem(name: "email", value: email))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)

        // Parse Atom XML response
        let parser = ArxivAtomParser()
        let entries = try parser.parse(data: data)

        guard let entry = entries.first else {
            throw ResearchClientError.noResultsFound
        }

        let year = Calendar.current.component(.year, from: entry.published)

        return PaperMetadata(
            id: entry.id,
            title: entry.title,
            authors: entry.authors,
            year: year,
            venue: "arXiv",
            abstract: entry.summary,
            url: URL(string: entry.id),
            citationCount: nil,
            isOpenAccess: true,
            source: "arxiv",
            relevanceScore: 0.0,
            tags: entry.categories
        )
    }
}

// MARK: - arXiv Atom Parser

/// Simple parser for arXiv Atom XML responses.
private class ArxivAtomParser: NSObject, XMLParserDelegate {
    private var entries: [ArxivEntry] = []
    private var currentEntry: ArxivEntry?
    private var currentElement = ""
    private var currentText = ""

    struct ArxivEntry {
        var id: String = ""
        var title: String = ""
        var authors: [String] = []
        var published = Date()
        var summary: String = ""
        var categories: [String] = []
    }

    func parse(data: Data) throws -> [ArxivEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return entries
    }

    // XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "entry" {
            currentEntry = ArxivEntry()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var entry = currentEntry else { return }

        switch elementName {
        case "id":
            entry.id = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "title":
            entry.title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "author":
            let name = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                entry.authors.append(name)
            }
        case "published":
            let formatter = ISO8601DateFormatter()
            entry.published = formatter.date(from: currentText) ?? Date()
        case "summary":
            entry.summary = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category":
            let category = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !category.isEmpty {
                entry.categories.append(category)
            }
        case "entry":
            entries.append(entry)
            currentEntry = nil
        default:
            break
        }

        currentEntry = entry
    }
}

// MARK: - Research Client Service

/// Service that orchestrates research clients.
public actor ResearchClientService {
    private let config: ResearchClientConfig
    private let researchClient: ResearchClient

    public init(config: ResearchClientConfig) throws {
        self.config = config
        self.researchClient = DefaultResearchClient(config: config)
    }

    /// Conduct research for a topic specification.
    public func conductResearch(for topicSpec: TopicSpec) async throws -> ResearchBundle {
        let startTime = Date()

        // Generate search queries
        let queries = topicSpec.generateQueries()
        var allPapers: [PaperMetadata] = []

        // Execute searches
        for query in queries.prefix(3) {  // Limit to 3 queries to avoid overwhelming APIs
            do {
                let papers = try await researchClient.searchPapers(
                    query: query,
                    limit: topicSpec.maxPapers / queries.count,
                    minYear: topicSpec.minYear
                )
                allPapers.append(contentsOf: papers)

                // Rate limiting between queries
                try await Task.sleep(nanoseconds: UInt64(config.rateLimitDelay * 1_000_000_000))
            } catch {
                print("Query '\(query)' failed: \(error)")
            }
        }

        // Remove duplicates by ID
        var uniquePapers: [String: PaperMetadata] = [:]
        for paper in allPapers {
            uniquePapers[paper.id] = paper
        }
        let papers = Array(uniquePapers.values)

        // Calculate adequacy score
        let adequacyScore = calculateAdequacyScore(papers: papers, topicSpec: topicSpec)

        // Extract notes (simple extraction for now)
        let extractedNotes = extractNotes(from: papers)

        // Create provenance record
        let provenance = ProvenanceRecord(
            engineId: "ResearchClientService",
            engineType: "ResearchClient",
            capabilities: ["net.openalex.api.read", "net.arxiv.api.read"],
            conductedAt: startTime,
            duration: Date().timeIntervalSince(startTime),
            sourcesConsulted: papers.map { $0.source }.unique(),
            processHash: UUID().uuidString
        )

        // Create research bundle
        return ResearchBundle(
            topicSpec: topicSpec,
            papers: papers,
            extractedNotes: extractedNotes,
            doctrineLinks: extractDoctrineLinks(from: papers, for: topicSpec),
            provenance: provenance,
            adequacyScore: adequacyScore,
            metadata: [
                "queries_executed": "\(queries.count)",
                "papers_found": "\(papers.count)",
                "compliance_level": config.complianceLevel.rawValue
            ]
        )
    }

    /// Calculate adequacy score for research.
    private func calculateAdequacyScore(papers: [PaperMetadata], topicSpec: TopicSpec) -> Double {
        var score = 0.0
        let maxScore = 10.0

        // Paper count (max 3 points)
        let paperCountScore = min(Double(papers.count) / 10.0, 3.0)
        score += paperCountScore

        // Recency (max 2 points)
        let recentPapers = papers.filter { $0.isRecent }
        if !recentPapers.isEmpty {
            score += 2.0
        }

        // Citation impact (max 2 points)
        let highlyCitedPapers = papers.filter { $0.isHighlyCited }
        if !highlyCitedPapers.isEmpty {
            score += 2.0
        }

        // Venue diversity (max 1 point)
        let venues = Set(papers.compactMap { $0.venue })
        if venues.count >= 3 {
            score += 1.0
        }

        // Institution diversity (max 1 point)
        let institutions = Set(papers.compactMap { $0.primaryInstitution })
        if institutions.count >= 3 {
            score += 1.0
        }

        // Open access compliance (max 1 point)
        let openAccessPapers = papers.filter { $0.isOpenAccess }
        if openAccessPapers.count >= papers.count / 2 {
            score += 1.0
        }

        return min(score / maxScore, 1.0)
    }

    /// Extract simple notes from papers.
    private func extractNotes(from papers: [PaperMetadata]) -> [ResearchNote] {
        var notes: [ResearchNote] = []

        for paper in papers {
            // Extract approach from abstract
            if let abstract = paper.abstract {
                let sentences = abstract.components(separatedBy: ". ").prefix(3)
                for sentence in sentences {
                    if sentence.lowercased().contains("propose") || sentence.lowercased().contains("introduce") {
                        notes.append(ResearchNote(
                            paperId: paper.id,
                            noteType: .approach,
                            content: sentence,
                            confidence: 0.8
                        ))
                    }

                    if sentence.lowercased().contains("achieve") || sentence.lowercased().contains("improve") {
                        notes.append(ResearchNote(
                            paperId: paper.id,
                            noteType: .finding,
                            content: sentence,
                            confidence: 0.7
                        ))
                    }

                    if sentence.lowercased().contains("limit") || sentence.lowercased().contains("challenge") {
                        notes.append(ResearchNote(
                            paperId: paper.id,
                            noteType: .limitation,
                            content: sentence,
                            confidence: 0.6
                        ))
                    }
                }
            }
        }

        return notes
    }

    /// Extract doctrine links from papers.
    private func extractDoctrineLinks(from papers: [PaperMetadata], for topicSpec: TopicSpec) -> [DoctrineDomain: [String]] {
        var links: [DoctrineDomain: [String]] = [:]

        for paper in papers {
            // Check paper tags against doctrine domains
            for tag in paper.tags {
                let tagLower = tag.lowercased()

                // Map tags to doctrine domains
                if tagLower.contains("security") || tagLower.contains("privacy") {
                    links[.privacy, default: []].append(tag)
                }

                if tagLower.contains("accessibility") || tagLower.contains("a11y") {
                    links[.accessibility, default: []].append(tag)
                }

                if tagLower.contains("software") || tagLower.contains("engineering") {
                    links[.softwareEngineering, default: []].append(tag)
                }

                if tagLower.contains("statistic") || tagLower.contains("probability") {
                    links[.statistics, default: []].append(tag)
                }

                if tagLower.contains("computer") || tagLower.contains("cs") {
                    links[.computerScience, default: []].append(tag)
                }
            }
        }

        // Add topic spec doctrine tags
        for domain in topicSpec.doctrineTags {
            links[domain, default: []].append(topicSpec.moduleName)
        }

        return links
    }
}

// MARK: - Helper Extensions

private extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
