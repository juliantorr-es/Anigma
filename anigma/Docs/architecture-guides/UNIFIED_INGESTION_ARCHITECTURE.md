---
title: "Unified Ingestion Architecture"
description: "Architectural guide for Anigma's multimodal data ingestion, isolated parsing, and semantic chunking."
audience: ["architects", "backend engineers"]
complexity: "advanced"
status: "active"
last_updated: "2026-05-01"
---

# Unified Ingestion Architecture

Historically, Anigma relied on fragmented ingestion pipelines (`BuildIngest` for Swift, `DiaplasionPipeline` for PDFs, `PolytroposModule` for video). This shallow architecture forced callers to act as routers and resulted in inconsistent chunking for RAG (Retrieval-Augmented Generation). 

The 2026 architecture introduces a unified, deep ingestion pipeline built around three core mandates: a single front door, crash-resilient parsing adapters, and centralized semantic chunking.

## 1. The Universal Front Door (`ArtifactIntakeAuthority`)

**Architectural Mandate:** Callers must never manually route files to specific parsers. All ingestion requests flow through the **`ArtifactIntakeAuthority`**.

- **Locality:** This module is the single source of truth for file signature detection (magic bytes), MIME type resolution, and initial governance checks (e.g., verifying the user is authorized to ingest the document).
- **Leverage:** The caller (UI, MCP agent, or CLI) simply calls `intake(url:)` or `intake(data:)`. The `ArtifactIntakeAuthority` automatically routes the payload to the correct processing adapter behind the `SubprocessWorker` seam.

## 2. Crash-Resilient Parsing Adapters

Parsing untrusted or malformed data is inherently dangerous. C-based AST parsers (`tree-sitter`) and PDF rendering engines (`PDFium`) can easily encounter segmentation faults or infinite recursive loops.

**Architectural Mandate:** Parsing untrusted payloads must *never* occur in the main `anigmad` process.

- **AST Parsing Isolation:** The codebase parsing logic (previously `BuildIngest`) has been moved behind the `SubprocessWorker` seam into `ASTParserWorkerExecutable`. 
- **Crash Recovery:** If a malformed `.swift` or `.cpp` file crashes the `tree-sitter` wrapper, the `SubprocessManager` catches the exit code, logs the specific file failure, and cleanly spins up a new worker. The main daemon is entirely unaffected.

## 3. Unified Semantic Chunking (`SemanticChunkingAuthority`)

Once an isolated adapter (PDF, Video, or AST) extracts the raw text or metadata, the data flows back into `anigmad` and must be vectorized for embeddings. Previously, each pipeline attempted to chunk its own data using naive fixed-length splitting, which destroys RAG precision.

**Architectural Mandate:** All extracted text flows through a single **`SemanticChunkingAuthority`** before embedding.

- **Locality:** The `SemanticChunkingAuthority` contains the exact tokenizer vocabulary of the currently active LLM. 
- **Context Optimization:** It utilizes 2026 industry best practices for semantic chunking: splitting text into meaning-preserving units (paragraphs, AST function blocks, or transcript sentences) and perfectly packing them to maximize the target model's token limits.
- **Leverage:** If a user switches from a 4k context window model to a 128k model, the chunking strategy automatically adapts globally in this one module, instantly optimizing all future ingests regardless of the source media type.