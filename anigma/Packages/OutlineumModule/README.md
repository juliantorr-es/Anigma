# OutlineumModule

**The image outlining and zine generation module.**

`OutlineumModule` provides automated systems for processing images into stylized outlines and organizing them into "zines" (small, self-published booklets). It leverages modern image processing techniques to replace legacy Command-Line processes with high-performance, native Swift implementations.

## Architecture

Outlineum follows a sequential processing pipeline within the ECS:

```mermaid
graph LR
    Image["Source Image"] --> Ingest["IngestSystem"]
    Ingest --> Outline["OutlineSystem"]
    Outline --> QA["OutlineQASystem"]
    
    QA --> Layout["ZineLayoutSystem"]
    Layout --> Export["ZineExportSystem"]
    
    Export --> Zine["Final Zine (PDF/Image)"]
```

## Core Components

### 1. ECS Components
- `ImageComponent`: Metadata about the original and processed image paths.
- `OutlineComponent`: Data related to the generated outline (paths, vector data).
- `OutlineQAComponent`: Results of the quality assurance checks (confidence, error flags).
- `ZineComponent`: Configuration and state for zine layout and export.

### 2. Processing Systems
- **IngestSystem**: Normalizes input images (resizing, color space conversion) to a standardized format.
- **OutlineSystem**: Performs edge detection (using CoreImage) and optional vectorization (tracing).
- **OutlineQASystem**: Analyzes the generated outline to ensure it meets legibility and style requirements.
- **ZineLayoutSystem**: Coordinates multiple images into a specific zine fold pattern (8-page, 16-page, etc.).
- **ZineExportSystem**: Renders the final layout to a printable format (typically PDF).

### 3. Workflows
Pre-configured automation sequences:
- `OutlineWorkflow`: The baseline pipeline for converting a single image into an outline.
- `ZineWorkflow`: An end-to-end pipeline for taking a collection of images and producing a zine.

## Usage

### Registering with ECS
```swift
import OutlineumModule

try await OutlineumModule.register(
    world: world,
    registry: workflowRegistry
)
```

### Running the Outline Pipeline
```swift
// Convenience method for single image processing
let result = await world.runOutlinePipeline(imagePath: "/path/to/cat.jpg")

if let qa = result.qa, qa.isAcceptable {
    print("Outline generated successfully!")
}
```

### Creating an Outline Job
```swift
let (job, entityId) = await OutlineumModule.createOutlineJob(
    imagePath: "/path/to/cat.jpg",
    world: world
)

// Submit to the JobSystem for asynchronous execution
await world.submit(job)
```

## Image Processing Techniques

The module utilizes several native platform technologies:
- **CoreImage**: Used for high-performance filters, grayscaling, and edge detection (Sobel/Canny).
- **Vision Framework**: Employed for saliency detection and refined boundary analysis.
- **Potrace (Optional)**: If the system detects `potrace` in the environment, it can perform high-quality vector tracing for scalable outputs.

## Thread Safety

- **Stateless Operation**: Systems are designed to be re-entrant and thread-safe.
- **File System Isolation**: Each operation is typically conducted in a dedicated work directory to prevent collisions.
- **Strict Concurrency**: Fully enabled across the module.

## Dependencies

- **AnigmaCore**: ECS framework and job management.
- **Foundation**: File system and basic types.
- **CoreImage/Vision** (macOS/iOS): Native image processing.

## See Also

- [Zine Layout Specification](../../Docs/design/zine-layout-patterns.md)
- [Edge Detection Parameters](../../Docs/design/outline-tuning.md)
