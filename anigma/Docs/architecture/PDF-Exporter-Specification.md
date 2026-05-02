# PDF Exporter Specification

**Version**: 1.0.0  
**Date**: 2025-01-27  
**Status**: Approved  
**Integration**: First-class daemon job pipeline

## Overview

The PDF Exporter is a governed pipeline that transforms Anigma book projects (chunks, metadata, assets) into press-ready PDFs suitable for home or professional printing. It treats LaTeX as a last-mile renderer trapped in a sandbox, with deterministic artifacts and receipts at every stage.

## Architecture Principles

1. **First-class daemon integration**: Not a standalone package, but integrated with existing job queue, vault authority, receipt engine
2. **Deterministic by default**: Same inputs → same artifacts, with explicit non-determinism markers
3. **Governance through receipts**: Every stage produces canonical artifacts with hashes and provenance
4. **Print-ready gates**: Structured diagnostics classify issues as blocking vs warnings
5. **Deep reuse**: Extends existing DocumentIRKit, capsule patterns, error models

## Package Structure

### Primary Packages
```
Packages/PDFExporterKit/
├── Sources/PDFExporterKit/
│   ├── Artifacts/           # Canonical artifact definitions
│   │   ├── BookProjectManifest.swift
│   │   ├── BookDocIR.swift                # Extends DocumentIRKit
│   │   ├── StyleBundle.swift
│   │   ├── LaTeXSourcePackage.swift
│   │   ├── BuildReport.swift
│   │   └── ToolchainReceipt.swift
│   ├── Models/
│   │   ├── PrintSettings.swift
│   │   ├── PageGeometry.swift
│   │   └── WarningsPolicy.swift           # Versioned artifact
│   └── LaTeXEmitter.swift                 # Strict escaping, label scheme

Packages/TeXCompileCapsule/
├── Sources/TeXCompileCapsule/
│   ├── TeXCompileCapsule.swift           # Actor wrapper
│   ├── TectonicIntegration.swift         # macOS sandboxed Tectonic
│   └── MultiPassStabilization.swift      # aux/toc/bbl/idx hash detection

Packages/BookExportCapsule/
├── Sources/BookExportCapsule/
│   ├── BookExportCapsule.swift           # Main orchestrator actor
│   ├── StageOrchestrator.swift           # Coordinates capsule pipeline
│   └── ExportReceiptBuilder.swift        # Builds final receipt
```

### Extensions to Existing Packages
- **DocumentIRKit**: Add BookDocIR extensions with book-specific nodes
- **TextChunkingCapsule**: Extend for ChunkNormalizerCapsule functionality
- **AnigmaDaemonCore**: Add export job handlers and worker registration
- **PDFCapsule**: Extend for PDFPostflightCapsule functionality

## Canonical Artifacts

### BookProjectManifest
```swift
struct BookProjectManifest: Codable, Hashable {
    let id: UUID
    let version: SemanticVersion
    let bookIdentity: BookIdentity
    let revision: String
    let locale: Locale
    let language: LanguageCode
    let paperSize: PaperSize
    let trimSize: TrimSize
    let margins: PageMargins
    let bindingType: BindingType            // perfect bound vs saddle stitch
    let printMode: PrintMode                // single-sided, duplex long edge
    let outputIntent: OutputIntent          // screen, home print, pro print
    let styleProfileId: String
    let chunkRefs: [ChunkReference]         // pointers by content hash
    let assetRefs: [AssetReference]
    let createdAt: Date
    let updatedAt: Date
}
```

### BookDocIR (extends DocumentIRKit)
```swift
enum BookDocIRNode {
    // Front matter
    case titlePage(TitlePageNode)
    case copyrightPage(CopyrightPageNode)
    case dedication(DedicationNode)
    case epigraph(EpigraphNode)
    case preface(PrefaceNode)
    case tableOfContents(TableOfContentsNode)
    
    // Body matter
    case chapter(ChapterNode)               // with recto/verso policy
    case section(SectionNode)
    
    // Back matter
    case appendix(AppendixNode)
    case bibliography(BibliographyNode)
    case index(IndexNode)
    case colophon(ColophonNode)
    
    // Special nodes
    case float(FloatNode)                   // figures/tables with placement
    case crossReference(CrossReferenceNode)
    case indexTerm(IndexTermNode)
    
    // Inherited from DocumentIRKit
    case paragraph(ParagraphNode)
    case list(ListNode)
    case table(TableNode)
    case codeBlock(CodeBlockNode)
    case blockQuote(BlockQuoteNode)
}

// Deterministic ID generation
struct BookNodeID: Hashable {
    let sourceChunkID: String
    let localPath: [Int]                    // hierarchical position
    let nodeType: String
}
```

### StyleBundle
```swift
struct StyleBundle: Codable, Hashable {
    let id: String
    let version: SemanticVersion
    let latexClass: String                  // e.g., "scrbook", "book"
    let packages: [LaTeXPackage]
    let themeParameters: ThemeParameters
    let fontSet: FontSet
    let layoutRules: LayoutRules
    let printRules: PrintRules
}

struct PrintRules {
    let mirrorMargins: Bool
    let gutterWidth: Measurement<UnitLength>
    let chapterOpensOnRecto: Bool
    let widowOrphanPolicy: WidowOrphanPolicy
    let hyphenationLanguage: LanguageCode
    let baselineGrid: BaselineGridPolicy?
}
```

### LaTeXSourcePackage
```swift
struct LaTeXSourcePackage: Codable {
    let manifest: SourceManifest
    let entrypoint: String                  // main.tex path
    let files: [SourceFile]
    
    struct SourceFile: Codable {
        let path: String
        let contentHash: String
        let expectedPath: String
    }
}
```

### BuildReport
```swift
struct BuildReport: Codable {
    let compilationPasses: [CompilationPass]
    let warnings: [ExportWarning]
    let errors: [ExportError]
    let printReadiness: PrintReadinessStatus
    let metrics: ExportMetrics
    
    struct ExportMetrics {
        let pageCount: Int
        let overfullBoxCount: Int
        let unresolvedReferences: Int
        let missingGlyphs: Int
        let fontSubstitutions: Int
        let floatPlacementWarnings: Int
    }
    
    enum PrintReadinessStatus: String, Codable {
        case ready = "READY"
        case needsAttention = "NEEDS_ATTENTION"
        case blocked = "BLOCKED"
        case failed = "FAILED"
    }
}
```

### ToolchainReceipt
```swift
struct ToolchainReceipt: Codable, Hashable {
    let id: String
    let toolchainType: ToolchainType        // tectonic, lualatex, xelatex
    let version: String
    let bundleHash: String
    let configuration: ToolchainConfig
    let createdAt: Date
}
```

## Compute Capsules

### 1. ChunkNormalizerCapsule
**Input**: Raw chunk content + per-chunk metadata  
**Output**: Normalized ChunkSet  
**Pattern**: Extends TextChunkingCapsule

```swift
actor ChunkNormalizerCapsule {
    private let config: CapsuleConfig
    private let diagnostics: DiagnosticsCollector
    
    func normalize(
        chunks: [RawChunk],
        strictMode: Bool
    ) async throws -> (ChunkSet, CapsuleReceipt) {
        // Deterministic processing:
        // 1. Unicode normalization (NFC)
        // 2. Whitespace normalization
        // 3. Line ending policy (LF)
        // 4. Paragraph boundary detection
        // 5. Non-printable character validation
    }
}
```

### 2. BookAssemblerCapsule
**Input**: Normalized ChunkSet + BookProjectManifest  
**Output**: BookDocIR  
**Pattern**: Builds on DocumentIRKit

```swift
actor BookAssemblerCapsule {
    func assemble(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest
    ) async throws -> (BookDocIR, CapsuleReceipt) {
        // 1. Resolve chapter ordering
        // 2. Embed chunk content into structural nodes
        // 3. Generate deterministic node IDs
        // 4. Map back to chunk IDs for traceability
    }
}
```

### 3. StyleResolverCapsule
**Input**: BookProjectManifest + StyleProfile ID  
**Output**: StyleBundle

```swift
actor StyleResolverCapsule {
    func resolve(
        manifest: BookProjectManifest,
        styleProfileId: String,
        themeParameters: ThemeParameters? = nil
    ) async throws -> (StyleBundle, CapsuleReceipt) {
        // 1. Load style profile from vault
        // 2. Apply theme overrides
        // 3. Validate print rules compatibility
        // 4. Generate deterministic StyleBundle
    }
}
```

### 4. LaTeXEmitterCapsule
**Input**: BookDocIR + StyleBundle  
**Output**: LaTeXSourcePackage

```swift
actor LaTeXEmitterCapsule {
    func emit(
        docIR: BookDocIR,
        styleBundle: StyleBundle
    ) async throws -> (LaTeXSourcePackage, CapsuleReceipt) {
        // 1. Strict escaping of text nodes
        // 2. Label generation from IR node IDs
        // 3. Code block handling with safe environments
        // 4. Math nodes as opaque TeX strings
        // 5. Asset path resolution
    }
}
```

### 5. TeXCompileCapsule
**Input**: LaTeXSourcePackage + ToolchainReceipt  
**Output**: PDFOutput + BuildReport

```swift
actor TeXCompileCapsule {
    func compile(
        sourcePackage: LaTeXSourcePackage,
        toolchain: ToolchainReceipt,
        maxPasses: Int = 5
    ) async throws -> (PDFOutput, BuildReport, CapsuleReceipt) {
        // 1. Setup sandboxed work directory
        // 2. Run Tectonic with no network
        // 3. Multi-pass stabilization detection
        // 4. Extract structured warnings/errors
        // 5. Generate BuildReport with metrics
    }
}
```

### 6. PDFPostflightCapsule
**Input**: PDFOutput + BuildReport  
**Output**: Final PDF + PostflightReport  
**Pattern**: Extends existing PDFCapsule

```swift
actor PDFPostflightCapsule {
    func postflight(
        pdf: PDFOutput,
        report: BuildReport
    ) async throws -> (PDFOutput, PostflightReport, CapsuleReceipt) {
        // 1. Verify embedded fonts
        // 2. Check page boxes
        // 3. Validate PDF metadata
        // 4. Optional PDF/A validation
        // 5. Linearization for fast viewing
    }
}
```

## Daemon Integration

### Job Type Registration
```swift
// In DaemonServer.registerDefaultWorkers()
exportEngine.registerWorker(
    for: .pdfExport,
    worker: BookExportWorker()  // Uses BookExportCapsule
)

// Job type definition
extension JobType {
    static let pdfExport = JobType(rawValue: "pdf.export")
}
```

### Export Job Handler
```swift
// In DaemonServer+Jobs.swift
extension DaemonServer {
    func submitExportJob(_ spec: ExportJobSpec) async throws -> SubmitJobResponse {
        let job = JobSpec(
            typeId: "pdf.export",
            inputRefs: spec.inputRefs,
            outputRefs: spec.outputRefs,
            priority: spec.priority,
            metadata: spec.metadata
        )
        return try await submitJob(job)
    }
}
```

### Worker Implementation
```swift
actor BookExportWorker: Worker {
    let capsule: BookExportCapsule
    let vault: VaultAuthority
    let receiptEngine: ReceiptEngine
    
    func process(job: JobSpec) async throws -> JobResult {
        // 1. Load inputs from vault
        let manifest = try await vault.loadArtifact(
            BookProjectManifest.self,
            ref: job.inputRefs["manifest"]
        )
        
        // 2. Run capsule pipeline
        let result = try await capsule.export(manifest: manifest)
        
        // 3. Store artifacts
        let pdfRef = try await vault.storeArtifact(result.pdf)
        let reportRef = try await vault.storeArtifact(result.report)
        
        // 4. Generate receipt
        let receipt = try await receiptEngine.generateReceipt(
            for: job,
            inputs: job.inputRefs,
            outputs: ["pdf": pdfRef, "report": reportRef],
            metadata: result.metadata
        )
        
        // 5. Return result
        return JobResult(
            status: .completed,
            outputRefs: ["pdf": pdfRef, "report": reportRef],
            receiptRef: receipt.ref
        )
    }
}
```

## Sandboxing Strategy

### macOS Seatbelt Profile
```xml
<!-- Tectonic.sb -->
(version 1)
(deny default)
(allow file-read* (subpath "/path/to/vault/export-workspace"))
(allow file-write* (subpath "/path/to/vault/export-workspace"))
(allow file-read* (subpath "/path/to/tectonic-bundle"))
(allow process-exec (with no-sandbox) (literal "/usr/bin/tectonic"))
(deny network*)
(deny sysctl*)
(deny mach*)
```

### Controlled Environment
```swift
struct CompileEnvironment {
    let workDirectory: URL
    let assetDirectory: URL
    let cacheDirectory: URL?
    let environmentVariables: [String: String]
    let allowedPaths: [URL]
    let networkAllowed: Bool = false
    let shellEscapeAllowed: Bool = false
}
```

## Error Model

### Extended CapsuleCore Errors
```swift
extension CapsuleCore.Error {
    // Asset errors
    static let missingAsset = Self(
        code: "PDF_EXPORTER_MISSING_ASSET",
        message: "Required asset not found in vault",
        severity: .blocking
    )
    
    // Reference errors
    static let unresolvedReference = Self(
        code: "PDF_EXPORTER_UNRESOLVED_REFERENCE",
        message: "Reference cannot be resolved",
        severity: .blocking
    )
    
    // Layout errors
    static let overfullBox = Self(
        code: "PDF_EXPORTER_OVERFULL_BOX",
        message: "Layout defect: overfull box detected",
        severity: .blocking,
        metadata: ["threshold": "0.5pt"]
    )
    
    // Font errors
    static let missingGlyph = Self(
        code: "PDF_EXPORTER_MISSING_GLYPH",
        message: "Required glyph not available in embedded fonts",
        severity: .blocking
    )
    
    static let fontSubstitution = Self(
        code: "PDF_EXPORTER_FONT_SUBSTITUTION",
        message: "Font substitution occurred",
        severity: .warning  // Blocking in strict mode
    )
    
    // Compilation errors
    static let stabilizationFailure = Self(
        code: "PDF_EXPORTER_STABILIZATION_FAILURE",
        message: "LaTeX compilation failed to stabilize within max passes",
        severity: .blocking
    )
}
```

## Caching Strategy

### Cache Key Generation
```swift
struct CacheKey: Hashable {
    let stage: ExportStage
    let inputHashes: [String: String]
    let configHash: String
    let toolchainHash: String?
}

enum ExportStage: String, Codable {
    case chunkNormalization
    case bookAssembly
    case styleResolution
    case latexEmission
    case compilation
    case postflight
}
```

### Cache Lookup
```swift
actor ExportCache {
    func lookup(
        stage: ExportStage,
        inputs: [String: any Artifact],
        config: ExportConfig,
        toolchain: ToolchainReceipt?
    ) async throws -> (any Artifact, CapsuleReceipt)? {
        let key = CacheKey(
            stage: stage,
            inputHashes: inputs.mapValues { $0.contentHash },
            configHash: config.contentHash,
            toolchainHash: toolchain?.contentHash
        )
        
        return try await vault.lookupCache(key: key)
    }
}
```

## CLI Interface

### Command Structure
```bash
# Create export job
anigma export create \
  --project manifest.json \
  --style profile-id \
  --strict \
  --output-dir ./exports

# Check job status
anigma export status <job-id>

# List artifacts
anigma export artifacts <job-id>

# Download specific artifact
anigma export artifacts <job-id> --type latex-source --output ./source

# Open generated PDF
anigma export pdf <job-id> --open

# Get build report
anigma export report <job-id> --format json
```

### Job Submission
```swift
struct ExportCreateCommand: Command {
    @Argument var projectPath: String
    @Option var style: String?
    @Flag var strict: Bool = false
    @Option var outputDir: String?
    
    func run() async throws {
        // 1. Load and validate project manifest
        let manifest = try BookProjectManifest.load(from: projectPath)
        
        // 2. Submit job to daemon
        let client = try DaemonClient()
        let response = try await client.submitExportJob(
            ExportJobSpec(
                manifest: manifest,
                styleProfileId: style,
                strictMode: strict,
                outputDir: outputDir
            )
        )
        
        // 3. Display job info
        print("Export job created: \(response.jobId)")
        print("Status: \(response.initialStatus)")
        print("Use 'anigma export status \(response.jobId)' to check progress")
    }
}
```

## Golden Corpus

### Test Document Specifications

#### 1. Short Prose Book
- **Purpose**: Test basic typography and hyphenation
- **Features**:
  - Smart quotes, em dashes, ellipses
  - Mixed English/French/German text for hyphenation
  - Nested emphasis (bold, italic, small caps)
  - Block quotes with citations
- **Expected failures**: None in strict mode

#### 2. Technical Chapter
- **Purpose**: Test code blocks and technical content
- **Features**:
  - Long unbreakable code lines (80+ chars)
  - URLs in text
  - Inline code with special characters
  - Syntax-highlighted code blocks
  - Mathematical notation (via MathJax/KaTeX)
- **Expected failures**: Overfull boxes from long code lines

#### 3. Image-Heavy Document
- **Purpose**: Test asset handling and float placement
- **Features**:
  - Low DPI images (72 DPI)
  - Oversized tables that barely fit
  - Multiple floats per page
  - Captions with cross-references
  - SVG images with text
- **Expected failures**: Low DPI warnings, float placement issues

#### 4. Footnote Storm
- **Purpose**: Test reference resolution and page breaks
- **Features**:
  - Dense footnotes (5+ per page)
  - Nested citations
  - Cross-references between footnotes
  - Bibliography with multiple styles
- **Expected failures**: Page break issues, unresolved references

#### 5. Overfull Box Trigger
- **Purpose**: Test BuildReport classification
- **Features**:
  - Intentionally long unbreakable string
  - Wide table with minimal margins
  - URL that exceeds line width
  - Mixed content designed to overflow
- **Expected failures**: Overfull box warnings (blocking in strict mode)

#### 6. Chapter Recto Starts
- **Purpose**: Test print-specific features
- **Features**:
  - Chapters that must start on odd pages
  - Blank verso page insertion
  - Running headers with chapter titles
  - Duplex margin flipping
- **Expected failures**: Incorrect page numbering if logic flawed

## Acceptance Criteria

### Phase 1 Completion
- [ ] BookProjectManifest schema defined and validated
- [ ] BookDocIR extensions integrated with DocumentIRKit
- [ ] ChunkNormalizerCapsule extends TextChunkingCapsule patterns
- [ ] BookAssemblerCapsule generates deterministic node IDs
- [ ] Export job type registered with daemon
- [ ] Basic CLI commands implemented

### Phase 2 Completion
- [ ] LaTeXEmitterCapsule with strict escaping
- [ ] TeXCompileCapsule with Tectonic integration
- [ ] Multi-pass stabilization detection
- [ ] Structured BuildReport with source mapping
- [ ] macOS sandboxing (controlled directory)

### Phase 3 Completion
- [ ] Warnings policy as versioned artifact
- [ ] BuildReport classification (blocking vs warning)
- [ ] Overfull box detection with threshold
- [ ] Font embedding validation
- [ ] Missing asset/glyph detection

### Phase 4 Completion
- [ ] ReferenceResolverCapsule with citation database
- [ ] BibliographyCapsule (deterministic .bib)
- [ ] IndexCapsule (basic \index{} support)
- [ ] PDFPostflightCapsule extends PDFCapsule
- [ ] Golden corpus passes all tests

## Performance Targets

### Compilation Time
- **Small book** (< 50 pages): < 30 seconds
- **Medium book** (50-200 pages): < 2 minutes
- **Large book** (200+ pages): < 5 minutes

### Cache Effectiveness
- **Cache hit rate**: > 80% for unchanged content
- **Cache storage**: < 1GB per 1000 exports
- **Cache lookup**: < 100ms

### Memory Usage
- **Peak memory**: < 512MB for typical books
- **Disk I/O**: Minimal through caching
- **Network**: Zero in production mode

## Governance Requirements

### Receipt Contents
Every capsule receipt must include:
1. **Input hashes**: All input artifact hashes
2. **Output hashes**: Generated artifact hashes
3. **Toolchain version**: Exact toolchain identity
4. **Configuration hash**: Warnings policy and settings
5. **Determinism marker**: Explicit if non-deterministic
6. **Performance metrics**: Execution time, memory usage

### Audit Trail
The system must support:
1. **Full provenance**: From final PDF back to source chunks
2. **Change impact**: Which chunks affect which pages
3. **Toolchain pinning**: Exact versions for reproducibility
4. **Policy compliance**: Warnings policy enforcement

## Security Considerations

### Sandbox Requirements
1. **No network access** in production mode
2. **Restricted file system** to workspace only
3. **No shell escape** from LaTeX
4. **Resource limits** on CPU, memory, disk
5. **Environment isolation** from host system

### Input Validation
1. **Chunk content**: Validate encoding, size limits
2. **Asset files**: Verify file types, size limits
3. **Style profiles**: Validate against schema
4. **Toolchain bundles**: Verify signatures/hashes

### Output Validation
1. **PDF structure**: Validate with qpdf or similar
2. **Font embedding**: Verify all fonts embedded
3. **Metadata**: Ensure no sensitive data leaked
4. **File size**: Reasonable bounds for content

## Monitoring & Observability

### Metrics to Collect
1. **Export success rate** by book type
2. **Compilation time** distribution
3. **Cache hit/miss rates**
4. **Warning/error frequency** by type
5. **Resource usage** (CPU, memory, disk)

### Logging Requirements
1. **Structured logs** in JSON format
2. **Correlation IDs** across pipeline stages
3. **Debug artifacts** accessible for failed jobs
4. **Performance traces** for optimization

## Future Extensions

### Planned Enhancements
1. **Traditional TeX Live backend** for feature completeness
2. **HTML/EPUB export** using same pipeline
3. **Interactive preview** during composition
4. **Batch export** for multiple formats
5. **Template marketplace** for style bundles

### Optional Features
1. **PDF/A compliance** for archival
2. **Color management** for professional print
3. **Bleed/crop marks** for print shops
4. **Variable data** for personalized printing
5. **Accessibility features** (tags, reading order)

---

**Last Updated**: 2025-01-27  
**Next Review**: 2025-02-27  
**Implementation Owner**: Engineering Team  
**Governance Owner**: Architecture Review Board