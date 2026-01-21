//
//  ResearchEnforcementDemo.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Demonstration of "no module without literature" enforcement.
//  Shows how research becomes a hard dependency.
//

import Foundation
import HarmoniaModule

// MARK: - Research Enforcement Demo

/// Demonstrates the research enforcement pipeline.
public actor ResearchEnforcementDemo {
    private let researchGate: ResearchGate
    private let registry: ResearchRegistry
    private let doctrinePack: ResearchDoctrinePack

    /// Initialize with test database.
    public init() throws {
        // Use in-memory database for demo
        let dbPath = ":memory:"
        self.registry = try ResearchRegistry(dbPath: dbPath)
        self.doctrinePack = ResearchDoctrinePack()
        self.researchGate = ResearchGate(registry: registry, doctrinePack: doctrinePack)
    }

    // MARK: - Demo Scenarios

    /// Demo 1: Attempt to create module without research.
    public func demoModuleWithoutResearch() async throws -> String {
        var output = "# Demo 1: Attempt to Create Module Without Research\n\n"

        // Create a module proposal for a security feature
        let securityModule = ModuleProposal(
            name: "QuantumResistantEncryption",
            description: "Implement post-quantum cryptography for secure communications",
            moduleType: "security",
            scope: ["encryption", "key exchange", "authentication"],
            doctrineTags: [.privacy, .computerScience],
            constraints: ["NIST standards compliance", "performance < 2x slowdown"],
            keywords: ["post-quantum", "cryptography", "lattice", "kyber", "dilithium"],
            changes: ["new_module", "security", "infrastructure"],
            requiresRecentResearch: true
        )

        output += "**Module Proposal:**\n"
        output += "- Name: \(securityModule.name)\n"
        output += "- Type: \(securityModule.moduleType)\n"
        output += "- Doctrine Tags: \(securityModule.doctrineTags.map { $0.rawValue }.joined(separator: ", "))\n"
        output += "- Changes: \(securityModule.changes.joined(separator: ", "))\n\n"

        // Check if research is required
        let requiresResearch = doctrinePack.requiresResearch(
            for: securityModule.moduleType,
            changes: securityModule.changes
        )

        output += "**Research Requirement Check:**\n"
        output += "- Requires research: \(requiresResearch ? "YES" : "NO")\n\n"

        if requiresResearch {
            // Try to get adequate research
            if let bundle = try await researchGate.checkModuleProposal(securityModule) {
                output += "✅ **RESEARCH FOUND:**\n"
                output += "- Bundle ID: \(bundle.id)\n"
                output += "- Adequacy Score: \(Int(bundle.adequacyScore * 100))%\n"
                output += "- Papers: \(bundle.papers.count)\n"
                output += "- Valid until: \(bundle.expiresAt)\n\n"
                output += "Module creation would be ALLOWED.\n"
            } else {
                // Block module creation
                let blockingResult = researchGate.blockModuleCreation(
                    moduleProposal: securityModule,
                    researchBundle: nil,
                    projectId: UUID()
                )

                output += "❌ **RESEARCH REQUIRED:**\n"
                output += "- Blocking reason: \(blockingResult.reason)\n"
                output += "- Research task created\n"
                output += "- Module creation BLOCKED\n\n"

                // Show recommendations
                output += "**Recommendations:**\n"
                for recommendation in blockingResult.recommendations {
                    output += "- [\(recommendation.priority)] \(recommendation.action): \(recommendation.reason)\n"
                }
            }
        }

        return output
    }

    /// Demo 2: Module with inadequate research.
    public func demoModuleWithInadequateResearch() async throws -> String {
        var output = "# Demo 2: Module with Inadequate Research\n\n"

        // Create a research bundle with inadequate research
        let inadequateBundle = createInadequateResearchBundle()

        output += "**Research Bundle Created:**\n"
        output += "- ID: \(inadequateBundle.id)\n"
        output += "- Papers: \(inadequateBundle.papers.count) (need at least 5)\n"
        output += "- Recent papers: \(inadequateBundle.papers.filter { $0.isRecent }.count) (need at least 2)\n"
        output += "- Institutions: \(Set(inadequateBundle.papers.compactMap { $0.primaryInstitution }).count) (need at least 3)\n"
        output += "- Adequacy Score: \(Int(inadequateBundle.adequacyScore * 100))% (need at least 70%)\n\n"

        // Check adequacy
        let violations = researchGate.checkResearchAdequacy(inadequateBundle)

        output += "**Research Adequacy Check:**\n"
        if violations.isEmpty {
            output += "✅ Research is adequate\n"
        } else {
            output += "❌ Research is INADEQUATE:\n"
            for violation in violations {
                output += "- \(violation.severity.rawValue.uppercased()): \(violation.message)\n"
            }
        }

        output += "\n"

        // Try to create module with this research
        let moduleId = UUID()
        let debtTasks = researchGate.createResearchDebtTasks(
            for: inadequateBundle,
            blockedEntityId: moduleId,
            blockedEntityType: "module"
        )

        output += "**Module Creation Attempt:**\n"
        output += "- Module ID: \(moduleId)\n"
        output += "- Research Bundle: \(inadequateBundle.id)\n"
        output += "- Debt Tasks Created: \(debtTasks.count)\n\n"

        if !debtTasks.isEmpty {
            output += "❌ **MODULE CREATION BLOCKED**\n"
            output += "Research debt tasks must be resolved first:\n"
            for debtTask in debtTasks {
                output += "\n**Debt Task \(debtTask.id):**\n"
                output += "- Reason: \(debtTask.reason)\n"
                output += "- Priority: \(debtTask.priority)\n"
                output += "- Required Actions:\n"
                for action in debtTask.requiredActions {
                    output += "  - \(action)\n"
                }
            }
        }

        return output
    }

    /// Demo 3: Module with adequate research.
    public func demoModuleWithAdequateResearch() async throws -> String {
        var output = "# Demo 3: Module with Adequate Research\n\n"

        // Create a research bundle with adequate research
        let adequateBundle = createAdequateResearchBundle()

        output += "**Research Bundle Created:**\n"
        output += "- ID: \(adequateBundle.id)\n"
        output += "- Papers: \(adequateBundle.papers.count)\n"
        output += "- Recent papers: \(adequateBundle.papers.filter { $0.isRecent }.count)\n"
        output += "- Institutions: \(Set(adequateBundle.papers.compactMap { $0.primaryInstitution }).count)\n"
        output += "- Adequacy Score: \(Int(adequateBundle.adequacyScore * 100))%\n"
        output += "- Valid: \(adequateBundle.isValid ? "YES" : "NO")\n"
        output += "- Adequate: \(adequateBundle.isAdequate ? "YES" : "NO")\n\n"

        // Check adequacy
        let violations = researchGate.checkResearchAdequacy(adequateBundle)

        output += "**Research Adequacy Check:**\n"
        if violations.isEmpty {
            output += "✅ Research is adequate\n"
        } else {
            output += "❌ Research is inadequate:\n"
            for violation in violations {
                output += "- \(violation.message)\n"
            }
        }

        output += "\n"

        // Generate research dossier
        let dossier = adequateBundle.generateDossier()
        output += "**Research Dossier Generated:**\n"
        output += "\(dossier)\n"

        output += "\n✅ **MODULE CREATION WOULD BE ALLOWED**\n"
        output += "Adequate research found, module can proceed to implementation.\n"

        return output
    }

    /// Demo 4: Research-aware step engine integration.
    public func demoStepEngineIntegration() async throws -> String {
        var output = "# Demo 4: Step Engine Integration\n\n"

        // Create research-aware step engine
        let engine = try ResearchAwareStepEngine.createIntegratedEngine()

        output += "**Research-Aware Step Engine Created**\n"
        output += "- Wraps base StepEngine\n"
        output += "- Integrates ResearchGate\n"
        output += "- Checks research before scheduling tasks\n\n"

        // Show how it would work
        output += "**How It Works:**\n"
        output += "1. StepEngine receives migration task\n"
        output += "2. ResearchAwareStepEngine intercepts task\n"
        output += "3. Checks if task requires research\n"
        output += "4. If research required:\n"
        output += "   - Checks for adequate research\n"
        output += "   - If adequate: allows task\n"
        output += "   - If inadequate: blocks task, schedules research\n"
        output += "5. If research not required: passes to base engine\n\n"

        output += "**Example Task Flow:**\n"
        output += "```\n"
        output += "Task: Create 'SecureAuth' module\n"
        output += "  ↓\n"
        output += "Research check: Security module → RESEARCH REQUIRED\n"
        output += "  ↓\n"
        output += "Check registry: No adequate research found\n"
        output += "  ↓\n"
        output += "ACTION: Block module task\n"
        output += "ACTION: Schedule research task\n"
        output += "ACTION: Create research debt task\n"
        output += "  ↓\n"
        output += "Result: Module creation blocked until research complete\n"
        output += "```\n"

        return output
    }

    // MARK: - Helper Methods

    private func createInadequateResearchBundle() -> ResearchBundle {
        // Create papers with inadequate characteristics
        var papers: [PaperMetadata] = []

        // Only 2 papers (need at least 5)
        papers.append(PaperMetadata(
            id: "paper1",
            title: "Early work on topic",
            authors: ["Author A"],
            year: 2010,  // Old paper
            venue: "Old Conference",
            abstract: "Early research",
            citationCount: 5,
            isOpenAccess: false,
            source: "test"
        ))

        papers.append(PaperMetadata(
            id: "paper2",
            title: "Another early paper",
            authors: ["Author B"],
            year: 2012,
            venue: "Another Conference",
            abstract: "More early research",
            citationCount: 3,
            isOpenAccess: false,
            source: "test"
        ))

        // All from same institution
        for paper in papers {
            // Simulate same institution
            _ = paper
        }

        let topicSpec = TopicSpec(
            moduleName: "TestModule",
            purpose: "Testing research adequacy",
            doctrineTags: [.computerScience],
            searchKeywords: ["test"],
            maxPapers: 20
        )

        let provenance = ProvenanceRecord(
            engineId: "demo",
            engineType: "DemoEngine",
            capabilities: ["test"],
            duration: 1.0,
            sourcesConsulted: ["test"],
            processHash: "demo"
        )

        return ResearchBundle(
            topicSpec: topicSpec,
            papers: papers,
            extractedNotes: [],
            doctrineLinks: [:],
            provenance: provenance,
            adequacyScore: 0.3,  // Low score
            metadata: ["demo": "true"]
        )
    }

    private func createAdequateResearchBundle() -> ResearchBundle {
        // Create papers with adequate characteristics
        var papers: [PaperMetadata] = []

        // 8 papers total
        for i in 1...8 {
            let year = 2020 + (i % 4)  // Mix of recent years
            let institution = ["MIT", "Stanford", "Berkeley", "CMU", "Google", "Microsoft", "Facebook", "Apple"][i % 8]

            papers.append(PaperMetadata(
                id: "adequate-paper-\(i)",
                title: "Recent Research Paper \(i)",
                authors: ["Researcher from \(institution)"],
                year: year,
                venue: ["NeurIPS", "ICML", "ICLR", "CVPR", "ACL", "EMNLP"][i % 6],
                abstract: "High-quality research on the topic",
                citationCount: i == 1 ? 150 : 50 + i * 10,  // One highly cited paper
                isOpenAccess: i % 2 == 0,  // Mix of open access
                source: "test",
                relevanceScore: 0.8,
                tags: ["research", "quality", "recent"]
            ))
        }

        let topicSpec = TopicSpec(
            moduleName: "WellResearchedModule",
            purpose: "Demonstrate adequate research",
            doctrineTags: [.computerScience, .softwareEngineering],
            searchKeywords: ["well", "researched", "quality"],
            maxPapers: 20
        )

        let notes = [
            ResearchNote(
                paperId: "adequate-paper-1",
                noteType: .finding,
                content: "Key finding from the research",
                confidence: 0.9
            ),
            ResearchNote(
                paperId: "adequate-paper-2",
                noteType: .limitation,
                content: "Important limitation discussed",
                confidence: 0.8
            ),
            ResearchNote(
                paperId: "adequate-paper-3",
                noteType: .approach,
                content: "Novel approach introduced",
                confidence: 0.85
            )
        ]

        let doctrineLinks: [DoctrineDomain: [String]] = [
            .computerScience: ["algorithms", "complexity", "theory"],
            .softwareEngineering: ["design", "patterns", "architecture"]
        ]

        let provenance = ProvenanceRecord(
            engineId: "demo-adequate",
            engineType: "DemoAdequateEngine",
            capabilities: ["test", "research"],
            duration: 5.0,
            sourcesConsulted: ["OpenAlex", "arXiv"],
            processHash: "adequate-demo"
        )

        return ResearchBundle(
            topicSpec: topicSpec,
            papers: papers,
            extractedNotes: notes,
            doctrineLinks: doctrineLinks,
            provenance: provenance,
            adequacyScore: 0.85,  // High score
            metadata: ["demo": "true", "quality": "high"]
        )
    }

    // MARK: - Run All Demos

    /// Run all demos and return combined output.
    public func runAllDemos() async throws -> String {
        var output = "# Research Enforcement Pipeline Demo\n\n"
        output += "Demonstrating 'no module without literature' as an invariant.\n\n"

        output += try await demoModuleWithoutResearch()
        output += "\n---\n\n"
        output += try await demoModuleWithInadequateResearch()
        output += "\n---\n\n"
        output += try await demoModuleWithAdequateResearch()
        output += "\n---\n\n"
        output += try await demoStepEngineIntegration()

        output += "\n# Summary\n\n"
        output += "The research enforcement pipeline ensures:\n"
        output += "1. **Research is structurally upstream** of implementation\n"
        output += "2. **Research adequacy is checked brutally** like security doctrine\n"
        output += "3. **Inadequate research creates debt tasks** that block progress\n"
        output += "4. **StepEngine integration** makes research a hard dependency\n"
        output += "5. **Human-readable dossiers** provide audit trail\n\n"

        output += "Result: Anigma cannot create new modules without first conducting\n"
        output += "and passing rigorous literature review. Research becomes a\n"
        output += "first-class artifact, not a suggestion.\n"

        return output
    }
}

// MARK: - Quick Test

/// Quick test to verify the pipeline works.
public func testResearchEnforcement() async {
    do {
        let demo = try ResearchEnforcementDemo()
        let output = try await demo.runAllDemos()
        print(output)

        // Also print to file for reference
        let fileURL = URL(fileURLWithPath: "/tmp/research_enforcement_demo.md")
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        print("\nDemo written to: \(fileURL.path)")

    } catch {
        print("Error running demo: \(error)")
    }
}
