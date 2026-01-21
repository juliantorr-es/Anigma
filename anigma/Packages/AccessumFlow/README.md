# AccessumFlow

**High-level orchestrator for accessibility transformation workflows.**

`AccessumFlow` is an "operator shell" that coordinates the execution of multiple specialized pipelines—`Diaplasion`, `Outlineum`, and `MLWorker`—to fulfill complex accessibility transformation requests. It manages a persistent ledger of runs and ensures end-to-end deterministic verification.

## Role in the Ecosystem

This tool acts as the "manager of managers." It bridges the gap between individual media processing pipelines and the high-level intent system, providing a single point of orchestration for multi-stage transformations.

## Usage

### Run an Accessibility Flow
Execute the full suite of transformations for a given specification:
```bash
swift run accessum-flow --spec my_document.json
```

### Replay a Previous Run
Re-verify a specific run from the ledger:
```bash
swift run accessum-flow --replay <run-id>
```

### List Previous Runs
(TBA via Admin subcommands)
```bash
swift run accessum-flow admin list
```

## Workflow Stages

A typical `AccessumFlow` run involves:

1. **DiaplasionStep**: OCR and generation of searchable PDFs.
2. **MLStep**: Generating vector embeddings for semantic search using `MLWorkerExecutable`.
3. **OutlineumStep**: Generating preview outlines/zines for visual verification.
4. **Ledger Recording**: Storing the results and traces in a local SQLite database (`accessum.db`).

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--spec` | `-s` | Path to the transformation spec JSON. | Bundled fixture. |
| `--output-base`| `-o` | base directory for Accessum artifacts. | `~/Library/Application Support/Anigma/Accessum` |
| `--replay` | | Run ID to re-verify. | N/A |
| `--retention-days`| | Automatically prune old ledger entries. | 30 |

## The Accessum Ledger

`AccessumFlow` maintains a persistent record of every transformation in an SQLite database. This ledger includes:
- **Run ID**: A deterministic hash of inputs and pipeline versions.
- **Trace History**: Links to the `trace.json` for every underlying pipeline.
- **Metrics**: End-to-end duration and step-level performance data.
- **Replay Command**: The exact command needed to re-verify the run.

## Hardware Requirements

- **MLX Support**: ML steps require Apple Silicon for optimal performance via the `MLWorkerExecutable`.
- **macOS 14+**: Required for Vision-based OCR and CoreGraphics rendering.

## Dependencies

- **AnigmaCore**: ECS and context management.
- **DatabaseCore**: Persistent ledger storage.
- **DiaplasionModule**: Media transformation.
- **OutlineumModule**: preview generation.
- **MLWorkerCommon**: ML orchestration.
- **ArgumentParser**: CLI interface.

## License

Part of the Anigma project. See LICENSE for details.
