//
//  DeepResearchEngine.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Structured note extraction engine for research papers.
//  Converts paper abstracts into structured ResearchNote objects.
//

import Foundation
import AnigmaCore
import HarmoniaModule

/// Engine for extracting structured notes from research papers.
/// Uses local LLM (when available) or rule-based extraction.
public struct DeepResearchEngine: Sendable {

    private let researchRegistry: ResearchRegistry
    private let capabilityChecker: CapabilityChecker

    public init(
        researchRegistry: ResearchRegistry,
        capabilityChecker: CapabilityChecker = .shared
    ) {
        self.researchRegistry = researchRegistry
        self.capabilityChecker = capabilityChecker
    }

    /// Process a research bundle to extract structured notes.
    /// Returns the updated bundle with extracted notes.
    public func extractStructuredNotes(
        from bundle: ResearchBundle
    ) async throws -> ResearchBundle {
        logInfo("Extracting structured notes from research bundle \(bundle.id)", category: "DeepResearchEngine")

        var updatedBundle = bundle
        var extractedNotes: [ResearchNote] = []

        // Process each paper in the bundle
        for paper in bundle.papers {
            do {
                let note = try await extractNote(from: paper)
                extractedNotes.append(note)
                logInfo("Extracted note from paper: \(paper.title)", category: "DeepResearchEngine")
            } catch {
                logWarning("Failed to extract note from paper '\(paper.title)': \(error)", category: "DeepResearchEngine")
                // Continue with other papers
            }
        }

        // Link notes to doctrine domains
        let doctrineLinkedNotes = linkNotesToDoctrine(notes: extractedNotes, bundle: bundle)

        // Update the bundle with extracted notes
        updatedBundle.notes = doctrineLinkedNotes
        updatedBundle.extractionCompletedAt = Date()

        // Save updated bundle
        try await researchRegistry.saveBundle(updatedBundle)

        logInfo("Extracted \(doctrineLinkedNotes.count) structured notes from \(bundle.papers.count) papers", category: "DeepResearchEngine")
        return updatedBundle
    }

    /// Extract a structured note from a single research paper.
    private func extractNote(from paper: ResearchPaper) async throws -> ResearchNote {
        // Check if we have LLM capability for summarization
        let hasLLMCapability = capabilityChecker.hasCapability("llm.local.summarize")

        if hasLLMCapability {
            return try await extractNoteWithLLM(from: paper)
        } else {
            return try extractNoteWithRules(from: paper)
        }
    }

    /// Extract note using local LLM (when available).
    private func extractNoteWithLLM(from paper: ResearchPaper) async throws -> ResearchNote {
        logInfo("Using LLM for note extraction from '\(paper.title)'", category: "DeepResearchEngine")
        // Until a local LLM client is wired, fall back to deterministic extraction
        // while labeling provenance to reflect the fallback path.
        return ResearchNote(
            id: UUID().uuidString,
            paperId: paper.id,
            title: paper.title,
            summary: extractKeyPoints(from: paper.abstract),
            keyFindings: extractFindings(from: paper.abstract),
            methodology: extractMethodology(from: paper.abstract),
            limitations: extractLimitations(from: paper.abstract),
            relevanceScore: calculateRelevance(from: paper),
            extractedAt: Date(),
            provenance: ["source": "llm_fallback", "model": "local"]
        )
    }

    /// Extract note using rule-based heuristics.
    private func extractNoteWithRules(from paper: ResearchPaper) throws -> ResearchNote {
        logInfo("Using rule-based extraction from '\(paper.title)'", category: "DeepResearchEngine")

        return ResearchNote(
            id: UUID().uuidString,
            paperId: paper.id,
            title: paper.title,
            summary: extractKeyPoints(from: paper.abstract),
            keyFindings: extractFindings(from: paper.abstract),
            methodology: extractMethodology(from: paper.abstract),
            limitations: extractLimitations(from: paper.abstract),
            relevanceScore: calculateRelevance(from: paper),
            extractedAt: Date(),
            provenance: ["source": "rule_extraction"]
        )
    }

    /// Link extracted notes to doctrine domains.
    private func linkNotesToDoctrine(
        notes: [ResearchNote],
        bundle: ResearchBundle
    ) -> [ResearchNote] {
        var linkedNotes: [ResearchNote] = []

        for var note in notes {
            // Extract keywords from note
            let keywords = extractKeywords(from: note)

            // Map keywords to doctrine domains
            let doctrineDomains = mapKeywordsToDoctrine(keywords: keywords)

            // Update note with doctrine links
            note.doctrineDomains = doctrineDomains
            note.keywords = keywords

            linkedNotes.append(note)
        }

        return linkedNotes
    }

    // MARK: - Rule-based Extraction Helpers

    private func extractKeyPoints(from abstract: String) -> String {
        // Simple rule: first 2-3 sentences
        let sentences = abstract.components(separatedBy: ". ")
        let keySentences = sentences.prefix(3).joined(separator: ". ")
        return keySentences + (sentences.count > 3 ? "..." : "")
    }

    private func extractFindings(from abstract: String) -> [String] {
        // Look for phrases like "we find", "results show", "demonstrate"
        let findingMarkers = ["we find", "results show", "demonstrate", "conclude", "evidence"]
        var findings: [String] = []

        for marker in findingMarkers {
            if let range = abstract.lowercased().range(of: marker) {
                let startIndex = abstract.index(range.lowerBound, offsetBy: 0)
                let endIndex = abstract.index(startIndex, offsetBy: min(100, abstract.distance(from: startIndex, to: abstract.endIndex)))
                let finding = String(abstract[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !finding.isEmpty {
                    findings.append(finding)
                }
            }
        }

        return findings.isEmpty ? ["Key findings extracted from abstract"] : findings
    }

    private func extractMethodology(from abstract: String) -> String {
        // Look for methodology indicators
        let methodMarkers = ["method", "approach", "technique", "framework", "model"]
        for marker in methodMarkers {
            if abstract.lowercased().contains(marker) {
                return "Uses \(marker)-based approach (extracted from abstract)"
            }
        }
        return "Methodology not specified in abstract"
    }

    private func extractLimitations(from abstract: String) -> [String] {
        // Look for limitation indicators
        let limitationMarkers = ["limitation", "constraint", "challenge", "future work", "further research"]
        var limitations: [String] = []

        for marker in limitationMarkers {
            if abstract.lowercased().contains(marker) {
                limitations.append("Mentions \(marker) in abstract")
            }
        }

        return limitations.isEmpty ? ["Limitations not specified in abstract"] : limitations
    }

    private func calculateRelevance(from paper: ResearchPaper) -> Double {
        // Simple relevance scoring based on paper metadata
        var score = 0.5  // Base score

        // Recency bonus (more recent = higher score)
        if let year = paper.year {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = currentYear - year
            if age <= 2 {
                score += 0.2
            } else if age <= 5 {
                score += 0.1
            }
        }

        // Citation count bonus
        if let citations = paper.citationCount, citations > 100 {
            score += 0.2
        } else if let citations = paper.citationCount, citations > 10 {
            score += 0.1
        }

        // Venue prestige bonus
        if let venue = paper.venue?.lowercased() {
            let prestigiousVenues = ["arxiv", "acl", "emnlp", "naacl", "iclr", "neurips", "icml"]
            if prestigiousVenues.contains(where: venue.contains) {
                score += 0.1
            }
        }

        return min(score, 1.0)  // Cap at 1.0
    }

    private func extractKeywords(from note: ResearchNote) -> [String] {
        // Extract keywords from note content
        var keywords: Set<String> = []

        // Add words from title
        let titleWords = note.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
        keywords.formUnion(titleWords.filter { $0.count > 3 })

        // Add words from summary
        let summaryWords = note.summary.lowercased().components(separatedBy: .whitespacesAndNewlines)
        keywords.formUnion(summaryWords.filter { $0.count > 3 })

        // Add findings
        for finding in note.keyFindings {
            let findingWords = finding.lowercased().components(separatedBy: .whitespacesAndNewlines)
            keywords.formUnion(findingWords.filter { $0.count > 3 })
        }

        return Array(keywords).sorted()
    }

    private func mapKeywordsToDoctrine(keywords: [String]) -> [DoctrineDomain] {
        // Map keywords to doctrine domains
        var domains: Set<DoctrineDomain> = []

        let keywordToDomain: [String: DoctrineDomain] = [
            "security": .security,
            "privacy": .security,
            "encryption": .security,
            "authentication": .security,
            "accessibility": .accessibility,
            "disability": .accessibility,
            "inclusive": .accessibility,
            "performance": .performance,
            "optimization": .performance,
            "efficiency": .performance,
            "maintainability": .maintainability,
            "readability": .maintainability,
            "documentation": .maintainability,
            "reliability": .reliability,
            "robustness": .reliability,
            "fault": .reliability,
            "usability": .usability,
            "user": .usability,
            "interface": .usability,
            "scalability": .scalability,
            "concurrent": .scalability,
            "distributed": .scalability
        ]

        for keyword in keywords {
            for (key, domain) in keywordToDomain {
                if keyword.contains(key) {
                    domains.insert(domain)
                }
            }
        }

        return Array(domains)
    }
}

// MARK: - ResearchNote Extension

extension ResearchNote {
    /// Create a research note with extracted information.
    public init(
        id: String,
        paperId: String,
        title: String,
        summary: String,
        keyFindings: [String],
        methodology: String,
        limitations: [String],
        relevanceScore: Double,
        extractedAt: Date,
        provenance: [String: String]
    ) {
        self.id = id
        self.paperId = paperId
        self.title = title
        self.summary = summary
        self.keyFindings = keyFindings
        self.methodology = methodology
        self.limitations = limitations
        self.relevanceScore = relevanceScore
        self.extractedAt = extractedAt
        self.provenance = provenance
        self.doctrineDomains = []
        self.keywords = []
        self.citations = []
        self.tags = []
    }
}
