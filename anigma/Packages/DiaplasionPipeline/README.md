# DiaplasionPipeline

**Accessible media transformation pipeline with deterministic traces.**

`DiaplasionPipeline` is the production executable for the `DiaplasionModule`. It coordinates the transformation of raw media (like images or PDF scans) into accessible formats (like searchable PDFs and plain text) using an automated, verifiable pipeline.

## Role in the Ecosystem

This pipeline is the "engine room" for media accessibility. It ensures that every student document processed by Anigma is correctly OCR'd, normalized, and exported with a full cryptographic trace of the transformation logic.

## Usage

### Run a Transformation
Run the pipeline using a specification file:
```bash
swift run diaplasion-pipeline --spec my_document_spec.json
```

### Replay a Trace
Verify the integrity of existing artifacts by replaying the pipeline from a trace:
```bash
swift run diaplasion-pipeline --spec my_document_spec.json --replay
```

## Key Features

- **Automated OCR**: Integrated with the Vision framework for high-accuracy text recognition.
- **Text Normalization**: Canonicalizes whitespace and Unicode normalization for consistent indexing.
- **Searchable PDF Generation**: Embeds OCR text into PDFs using CoreText and CoreGraphics.
- **Cryptographic Tracing**: Generates a `trace.json` containing hashes of every input, step, and output.
- **Git Integration**: Records the specific source code commit used to generate the artifacts.

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--spec` | `-s` | Path to the pipeline specification JSON. | Bundled "happy-path" fixture. |
| `--output-base`| `-o` | Base directory for storing artifacts. | `Artifacts/diaplasion` |
| `--replay` | | Re-verify existing artifacts against the trace. | `false` |

## Pipeline Trace (`trace.json`)

The generated trace file provides a deterministic audit log, including:
- **Input Details**: Hashes and byte counts for every source file.
- **Step Logs**: Results and metadata for each pipeline stage (e.g., OCR confidence).
- **Output Hashes**: Cryptographic digests of the final plain text and PDF artifacts.
- **Provenance**: Pipeline version and source commit.

## Dependencies

- **AnigmaCore**: Basic infrastructure.
- **DiaplasionModule**: Core transformation logic.
- **Vision**: OCR engine (macOS).
- **CoreGraphics / CoreText**: PDF rendering (macOS).
- **ArgumentParser**: CLI interface.

## License

Part of the Anigma project. See LICENSE for details.
