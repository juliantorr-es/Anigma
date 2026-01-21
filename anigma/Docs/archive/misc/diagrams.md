# Architecture Diagrams

<DiagramShowcase />

## About These Diagrams

This page contains interactive visualizations of Anigma's two-tier architecture, designed to help developers and stakeholders understand the system's design and relationships.

### 🏗️ Architecture Diagrams
Visual representations of the Core Governance Layer and Capability Modules, showing how they interact and the security boundaries between them.

### 🔄 Workflow Diagrams  
Step-by-step visualizations of key processes like the agent pipeline, build procedures, and deployment flows.

### 📊 Data Flow Diagrams
Detailed sequence diagrams showing how data moves through the system, including ML worker evidence generation and verification processes.

## Usage

- **Click any diagram** to view it in detail
- **Download SVG** for high-quality vector graphics
- **Download PNG** for raster images and presentations
- **Mobile responsive** - works on all device sizes

## Technical Details

All diagrams are generated from Mermaid source files and automatically converted to both SVG and PNG formats during the build process. The source files are available in the `diagrams/source/` directory for modification and version control.

### File Formats
- **SVG**: Scalable vector graphics, ideal for web and documentation
- **PNG**: Raster images, optimized for presentations and downloads
- **Source**: Human-readable Mermaid files for easy editing

### Build Integration
Diagrams are automatically generated as part of the documentation build process:

```bash
npm run docs:generate-diagrams  # Generate all diagrams
npm run docs:build              # Build with diagrams
```

## Contributing

To add new diagrams:

1. Create `.mmd` files in `diagrams/source/{category}/`
2. Run `npm run docs:generate-diagrams`
3. Update relevant documentation pages to reference new diagrams
4. Commit both source and generated files

For detailed guidelines, see the [LLM Context documentation](/llm-context/00-two-tier-architecture-guide.md).