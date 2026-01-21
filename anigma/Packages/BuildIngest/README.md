# BuildIngest

**Build diagnostic ingestion and structured evidence capture.**

`BuildIngest` is a specialized tool that wraps the Swift compiler to capture build logs, parse diagnostics (errors and warnings), and store them as structured evidence in an SQLite database. It turns volatile "compiler screaming" into queryable incident response data.

## Role in the Ecosystem

This tool is critical for maintaining repository health. It provides the structured data needed for build trend analysis, identifying recurring technical debt clusters, and ensuring that the CI/CD pipeline has a high-fidelity record of every build attempt.

## Usage

### Ingest a Build
Run a build for a specific target and ingest its diagnostics:
```bash
swift run build-ingest HarmoniaModule --configuration debug
```

### Key Features

- **Compiler Wrapping**: Intercepts `swift build` output in real-time.
- **Diagnostic Parsing**: Automatically extracts file paths, line numbers, and severity from compiler output.
- **Git State Capture**: Records the specific commit, branch, and working tree status (dirty/clean) for every build.
- **Leveled Evidence**: Stores diagnostics as structured records linked to a specific build session.
- **Provenance**: Calculates hashes of the build environment and toolchain versions.

## Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `--configuration`| Build configuration (`debug` or `release`). | `debug` |
| `--toolchain` | Toolchain identifier to record. | `swift-5.9` |
| `--session-id` | Custom session ID for grouping builds. | UUID |
| `--working-directory`| Directory to run the build in. | current dir |

## Database Schema

`BuildIngest` populates several tables in the evidence database:

- **build_sessions**: records the metadata for a build attempt (target, git state, status).
- **build_diagnostics**: stores individual compiler errors and warnings.
- **build_git_states**: captures the state of the repository at build time.

## Supported Diagnostics

| Severity | Description |
|----------|-------------|
| `error` | Compilation failures that block the build. |
| `warning`| Compiler warnings, including Swift 6 concurrency warnings. |
| `note` | Additional context provided by the compiler for an error/warning. |

## Dependencies

- **DatabaseCore**: Persistent storage for build evidence.
- **ArgumentParser**: CLI interface.
- **CryptoKit**: For generating diff and context hashes.

## License

Part of the Anigma project. See LICENSE for details.
