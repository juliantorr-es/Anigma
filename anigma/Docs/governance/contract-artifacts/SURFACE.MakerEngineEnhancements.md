# MAKER Engine Enhancements Surface Contract

## Purpose
This surface exists to provide: native library adapters that materially improve MAKER's core capabilities with parallel-agent safe operations, deterministic behavior, and governance compliance.

## Authority Boundary
Surface owner: Sources/MakerEngineEnhancements  
Allowed call sites: AnigmaCore.MakerEngine, HarmoniaModule.MakerIntegration  
Implementation modules: GitEngine, RepoMapIndexer, SafeRegexEngine, PolicyExecutor

Hard rule: No direct native library access outside this surface.

## Core Abstraction
```swift
public protocol NativeAdapter: Sendable {
    associatedtype Config: Sendable
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    var config: Config { get }
    func process(_ input: Input) async throws -> Output
    func validatePreconditions(for input: Input) -> ValidationResult
}
```

## Surface API

### 1. GitEngine - libgit2 Integration
```swift
public actor GitEngine: NativeAdapter {
    public struct Config: Sendable {
        let maxConcurrentOperations: Int
        let operationTimeout: TimeInterval
        let baseCommitAnchoring: Bool
    }
    
    public struct DiffInput: Sendable {
        let repositoryPath: String
        let baseCommit: String
        let targetCommit: String
        let fileFilter: [String]?
    }
    
    public struct DiffOutput: Sendable {
        let diffHash: String
        let hunks: [DiffHunk]
        let conflicts: [MergeConflict]
        let operationReceipt: OperationReceipt
    }
    
    public func generateDeterministicDiff(_ input: DiffInput) async throws -> DiffOutput
    public func detectMergeConflicts(_ input: MergeInput) async throws -> [MergeConflict]
    public func createParallelWorktree(_ input: WorktreeInput) async throws -> String
}
```

### 2. RepoMapIndexer - tree-sitter Integration
```swift
public actor RepoMapIndexer: NativeAdapter {
    public struct Config: Sendable {
        let incrementalParsing: Bool
        let maxCacheSize: Int
        let supportedLanguages: [Language]
    }
    
    public struct IndexInput: Sendable {
        let repositoryPath: String
        let filePaths: [String]
        let incrementalChanges: [FileChange]?
    }
    
    public struct IndexOutput: Sendable {
        let symbols: [Symbol]
        let references: [Reference]
        let parseReceipt: ParseOperationReceipt
    }
    
    public func buildSymbolIndex(_ input: IndexInput) async throws -> IndexOutput
    public func updateIndexIncremental(_ changes: [FileChange]) async throws -> IndexUpdate
    public func resolveSymbol(_ query: SymbolQuery) async throws -> [Symbol]
}
```

### 3. SafeRegexEngine - RE2 Integration
```swift
public actor SafeRegexEngine: NativeAdapter {
    public struct Config: Sendable {
        let maxExecutionTime: TimeInterval
        let maxMemoryUsage: Int64
        let deterministicOrdering: Bool
    }
    
    public struct MatchInput: Sendable {
        let pattern: String
        let text: String
        let options: MatchOptions
    }
    
    public struct MatchOutput: Sendable {
        let matches: [RegexMatch]
        let executionTime: TimeInterval
        let operationReceipt: RegexOperationReceipt
    }
    
    public func findMatches(_ input: MatchInput) async throws -> MatchOutput
    public func validatePattern(_ pattern: String) async throws -> PatternValidation
    public func generateCandidates(_ input: CandidateInput) async throws -> [String]
}
```

### 4. PolicyExecutor - WASM Integration
```swift
public actor PolicyExecutor: NativeAdapter {
    public struct Config: Sendable {
        let maxFuel: UInt64
        let maxMemoryPages: UInt32
        let allowedHostFunctions: [String]
    }
    
    public struct PolicyInput: Sendable {
        let moduleHash: String
        let functionName: String
        let arguments: [PolicyValue]
        let context: PolicyContext
    }
    
    public struct PolicyOutput: Sendable {
        let result: PolicyValue
        let fuelConsumed: UInt64
        let executionTime: TimeInterval
        let operationReceipt: WasmExecutionReceipt
    }
    
    public func executePolicy(_ input: PolicyInput) async throws -> PolicyOutput
    public func validateModule(_ moduleData: Data) async throws -> ModuleValidation
    public func loadPolicyModule(_ input: ModuleInput) async throws -> ModuleHandle
}
```

## Parallel Safety Requirements
All adapters must:
- Use actor isolation for thread safety
- Support concurrent operations on different inputs
- Provide deterministic output ordering
- Generate operation receipts for governance
- Respect resource limits and timeouts

## Evidence Generation
Every operation must generate receipts with:
- Operation type and inputs
- Cryptographic hashes of inputs/outputs
- Execution metrics (time, memory usage)
- Error details (if any)
- Actor context and session information

## Integration Contracts
- GitEngine integrates with MakerEngine quarantine system
- RepoMapIndexer replaces grep-based candidate generation
- SafeRegexEngine provides bounded candidate validation
- PolicyExecutor enables custom policy predicates safely

## Migration Path
1. Implement adapters behind existing MAKER interfaces
2. Gradual replacement of current "almost-git" logic
3. Backward compatibility during transition
4. Full replacement after governance validation

## Acceptance Criteria
- All adapters pass native library contract requirements
- Parallel safety verified with concurrent agent testing
- Evidence generation compliant with governance
- Performance meets or exceeds current implementations
- Integration tests with existing MAKER workflows

## Governance Hooks
- All native operations generate receipts in .opencode/ledger/
- Resource usage monitored and limited
- Policy compliance enforced for all adapters
- Quarantine system integration for failed operations

## Testing Requirements
Unit tests for each adapter with mocked native libraries  
Integration tests with real native libraries in CI  
Performance benchmarks vs current implementations  
Parallel safety tests with concurrent agents  
Fuzz testing for malicious inputs  
Governance receipt validation tests  
