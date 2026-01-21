# Swift 6 Migration Pipeline Status

## Phase 0: Data Pipeline Fixes (Completed)

### Changes Made

1. **Scout Finding Persistence**
   - Added `persistScoutFinding(_:db:)` and `persistScoutFindings(_:db:)` to `ScoutRegistry.swift`
   - Updated `Swift6DiagnosticScout.scan()` to include `suggestedFix` metadata
   - CLI now persists findings before creating migration tasks

2. **UUID Parsing Fixes**
   - Fixed `UUID.init(hexString:)` in `SQLiteHelpers.swift` to handle both dashed and dashless hex strings
   - Added proper null checking in `loadMigrationTasks()` and `loadFinding()`

3. **Date Handling**
   - Fixed ISO8601 date parsing in `loadFinding()` and `loadMigrationTasks()`
   - Dates are now properly serialized/deserialized

4. **Task ID Corruption**
   - Fixed C string conversion in tests (was causing 1-byte IDs instead of UUIDs)
   - Added validation and logging for task IDs

5. **File Transformation**
   - Extended `Swift6MigrationEngine.process()` with `applySendableConformance()` method
   - Implements regex-based transformation for `SendableConformance` findings
   - Creates `.bak` backup files before modifications
   - Handles edge cases (existing inheritance, where clauses, etc.)

6. **CLI Integration**
   - Updated `Main.swift` `Run.run()` to persist findings before task creation
   - Added proper logging for each pipeline step

### How to Test the Pipeline

```bash
# 1. Run Swift 6 scout (finds Sendable conformance issues)
./harmonia scout run swift6 --create-tasks

# 2. Process migration tasks (applies fixes)
./harmonia swift6 step --project-id 00000000-0000-0000-0000-000000000000 --limit 5

# 3. Check for backup files
find . -name "*.swift.bak" -type f

# 4. Verify changes
git diff
```

### Current Limitations

1. **Regex-based transformations**: Simple pattern matching, not AST-aware
2. **Single rule implemented**: Only `SendableConformance` problem kind
3. **Test failures**: One integration test still fails due to `loadFinding()` column order mismatch
4. **No AST integration**: Phase 1 will add SwiftSyntax-based transformations

## Phase 1: AST Infrastructure (TODO)

### Anchor Points for Integration

1. **`SwiftAstLens.swift`** (New file)
   - AST lookup service with caching
   - Inspiration: `inspiration/swift-ast-explorer/`
   - Key methods: `lookup(file:line:col:)`, `parseAndCache(filePath:)`

2. **`RewriteRule.swift`** (New file)
   - Protocol for idempotent transformations
   - Inspiration: `inspiration/SwiftRewriter/Sources/RewriteRule.swift`
   - Example: `AddSendableToValueTypesRule`

3. **`RewritePipeline.swift`** (New file)
   - Orchestrates rule execution
   - Inspiration: `inspiration/SwiftRewriter/Sources/RewritePipeline.swift`
   - Handles diff generation and patch application

4. **`AgSearchService.swift`** (New file)
   - Fast code search prefilter
   - Inspiration: `inspiration/the_silver_searcher/`
   - Reduces AST parsing scope

### Files to Extend

1. **`MigrationEngine.swift`**
   - Replace regex transformations with AST-based rules
   - Add `AstAnchor` support for precise location tracking
   - Integrate with `RewritePipeline`

2. **`ScoutRegistry.swift`**
   - Enrich findings with `AstAnchor` metadata
   - Use `AgSearchService` for candidate file discovery

3. **`SQLiteHelpers.swift`**
   - Add `ASTFacts` table for cached analysis
   - Store rule application metrics

### Performance Considerations

- **Cache strategy**: LRU cache keyed by (file path + content hash)
- **Incremental updates**: Parse only changed files
- **Background indexing**: Per-commit AST parsing
- **Memory limits**: ~100MB cache, ~100 files

### Governance Integration

- **Rule activation by trust tier**:
  - `.system`: Only safe, mechanical rules
  - `.trusted`: More aggressive refactors  
  - `.full`: All rules enabled
- **Version-tagged rule sets**: `swift6-migration`, `swift7-migration`
- **Bandit metrics**: Track rule success/failure rates

## Next Steps

1. **Add SwiftSyntax dependency** to `Package.swift` (separate `AnigmaASTServices` module)
2. **Implement `SwiftAstLens`** with file hash caching
3. **Create `RewriteRule` protocol** and first AST-based rule
4. **Integrate with migration engine**, keeping regex fallback
5. **Add `AgSearchService`** for fast prefiltering
6. **Update tests** to use new AST infrastructure

## Notes

- All inspiration patterns are in `inspiration/` folder (read-only)
- No external dependencies beyond SwiftSyntax
- Gradual migration from regex to AST
- Always create `.bak` backups before file modifications
- Test after each change: `swift test --filter MigrationPipelineTests`