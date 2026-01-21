# OutlineumZine

**Artifact-driven zine generation with deterministic provenance.**

`OutlineumZine` is a specialized executable that processes collections of images into a formatted "zine" (PDF). It uses an ECS-based pipeline to handle image normalization, outlining (vectorization-ready), and layout, while ensuring that the resulting artifact has a verifiable cryptographic link to its source inputs.

## Role in the Ecosystem

This tool serves as the production engine for the `OutlineumModule`. It demonstrates how the Anigma ECS can be used to coordinate complex media processing tasks into a single, signed output.

## Usage

### Generate a Zine
Execute the pipeline using a recipe specification:
```bash
swift run outlineum-zine --spec my_zine_recipe.json --output-base Artifacts/Production
```

### input Requirements
- **Recipe Spec**: A JSON file defining the zine title, version, and an array of image paths.
- **Source Images**: Images referenced in the recipe must be accessible at runtime.

## Pipeline Stages

`OutlineumZine` executes five distinct ECS systems in a strict sequence:

1. **IngestSystem**: Normalizes input images (resizing, color space adjustment).
2. **OutlineSystem**: Performs edge detection and prepares images for vectorization.
3. **OutlineQASystem**: Validates the quality of the generated outlines.
4. **ZineLayoutSystem**: Calculates page placement and ordering.
5. **ZineExportSystem**: Consolidates processed pages into the final PDF and signs the provenance.

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--spec` | `-s` | Path to the recipe JSON specification. | `Sources/OutlineumModule/TestFiles/zine-minimal/spec.json` |
| `--output-base`| `-o` | Base directory for storing generated artifacts. | `Artifacts/outlineum/zine` |

## Deterministic Provenance

Every zine generated includes a `provenance.json` file. This file contains:
- **Input Hash**: A SHA-256 digest of the recipe and all source image data.
- **Pipeline Version**: The specific version of the `OutlineumModule` used.
- **Entity State**: A snapshot of the ECS components at the time of export.

This ensures that any zine can be verified against its source material for authenticity.

## Dependencies

- **AnigmaCore**: ECS integration.
- **OutlineumModule**: Core media processing systems.
- **CryptoKit**: Deterministic hashing and signing.
- **ArgumentParser**: CLI interface.

## License

Part of the Anigma project. See LICENSE for details.
