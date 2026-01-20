# AnigmaCLI - Database Layer

## Responsibility
**CLI Persistence & Intelligence Backend**.
This module provides the unified database infrastructure for the Anigma CLI, combining traditional relational storage with vector embeddings and full-text search.

## Key Components

### 1. CLIDatabaseActor
The thread-safe entry point for all database operations.
- **Relational**: Manages sessions, runs, steps, and receipts.
- **Search**: Integrates FTS5 for lexical matching.
- **Semantic**: Integrates `sqlite-vec` for high-performance vector search.

### 2. CLIRunManager
Coordinates the lifecycle of AI agent runs.
- **Tracking**: records run start, status changes, and final outcomes.
- **Steps**: Tracks individual tool calls and reasoning steps.

### 3. CLIReceiptManager
Handles cryptographic evidence generation.
- **Chain of Trust**: Each receipt hashes the previous receipt, creating a tamper-evident audit trail.

### 4. CLILoopBreaker
Safety mechanism to prevent infinite reasoning loops.
- **Limits**: Enforces max steps, max time, and repeated tool call detection.

## Implementation Details
- **Backend**: SQLite via GRDB.
- **Extensions**: `sqlite-vec` for vector operations.
- **Concurrency**: Fully actor-isolated for safe concurrent access from multiple CLI commands.

## Maturity Level
**Level 5 (Golden)**: Strict concurrency enabled, full unit testing of database interactions, performance optimized.
