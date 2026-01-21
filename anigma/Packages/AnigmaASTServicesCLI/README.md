# AnigmaASTServicesCLI

**SwiftSyntax parsing and analysis services for architectural integrity.**

`AnigmaASTServicesCLI` (aliased as `anigma-ast-services`) is a standalone binary that provides static analysis of Swift source code using `SwiftSyntax`. It is designed to be called as a subprocess by the Harmonia ecosystem to keep heavy dependencies like `SwiftSyntax` out of the main application build chain.

## Role in the Ecosystem

This tool provides the "eyes" for architectural doctrine enforcement. It can parse Swift files, analyze their AST (Abstract Syntax Tree), and report on security vulnerabilities (e.g., hardcoded secrets) and code quality issues (e.g., forced unwrapping).

## Usage

### Parse a File
Extract basic AST metrics (node counts, size) from a file:
```bash
swift run anigma-ast-services parse --file Sources/MyModule/MyFile.swift
```

### Analyze a File
Run static analysis visitors on a file and get structured JSON findings:
```bash
swift run anigma-ast-services analyze --file Sources/MyModule/MyFile.swift --visitors security,quality
```

### Batch Analysis
Analyze all Swift files in a directory:
```bash
swift run anigma-ast-services batch --directory Sources/MyModule
```

### STDIO Mode (Daemon)
Keep the process alive and process analysis requests via stdin:
```bash
swift run anigma-ast-services stdio
```

## Key Features

- **Decoupled Architecture**: Isolation of `SwiftSyntax` dependencies.
- **Structured Output**: Emits deterministic JSON or NDJSON for easy machine parsing.
- **Pluggable Visitors**: Support for multiple analysis domains (Security, Quality, Doctrine).
- **Batch Processing**: Efficient directory-level analysis.

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--file` | | Path to a single Swift file to process. | N/A |
| `--directory`| | Path to a directory for batch analysis. | N/A |
| `--visitors` | | Comma-separated list of visitors to run. | `security,quality` |
| `--output-format`| | Format of the result (`json` or `ndjson`). | `json` |

## Analysis domains

### Security
Checks for potential security risks, such as hardcoded API keys, tokens, or passwords in string literals.

### Quality
Checks for common code quality issues, including force unwrapping and violated line length constraints.

## Dependencies

- **SwiftSyntax**: For high-fidelity Swift parsing.
- **SwiftParser**: For converting source text to AST.
- **ArgumentParser**: CLI interface.

## License

Part of the Anigma project. See LICENSE for details.
