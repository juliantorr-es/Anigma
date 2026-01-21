# Demo Module

## Happy Path Demo

The `HappyPathDemo` provides a comprehensive demonstration of the Export Job Ticket system, designed specifically for Franklin to showcase the complete pipeline in exactly two minutes.

### Features

The demo includes:

1. **Demo Script** - Automated sequence that runs the full export pipeline
2. **Sample Documents** - Pre-configured PDFs with tables, images, and multi-column layouts
3. **Quick Import** - One-click document import with automatic processing
4. **Instant Preview** - First 5 pages rendered immediately with source/export comparison
5. **Export Job Creation** - Print-like settings with plan freezing in one workflow
6. **ML Consent Flow** - Model download and consent with clear UI
7. **Real-time Progress** - Live export progress with pause/resume controls
8. **Support Bundle** - One-click diagnostic export with redaction
9. **Export Completion** - Final outputs with verification and receipts

### Running the Demo

```bash
swift run Demo
```

The demo will automatically:
- Initialize the demo environment
- Prepare sample documents (Financial Report, Product Catalog, Legal Contract)
- Perform quick document import with progress tracking
- Generate instant previews with quality comparison
- Create export jobs with print-quality settings
- Process ML consent flow for OCR, embedding, and captioning models
- Simulate real-time export progress with pause/resume
- Generate support bundles with redaction
- Complete export with verification and receipts
- Provide timing summary to ensure 2-minute target is met

### Configuration

The demo is configured with:
- Target duration: 120 seconds (2 minutes)
- Sample document count: 3
- Preview page count: 5
- Progress update interval: 0.5 seconds

### Sample Documents

The demo includes three sample documents:

1. **Financial_Report.pdf** - Multi-column financial report with tables and charts (12 pages, high complexity)
2. **Product_Catalog.pdf** - Product catalog with images and specifications (8 pages, medium complexity)
3. **Legal_Contract.pdf** - Legal contract with complex formatting (15 pages, medium complexity)

### Timing Checkpoints

The demo tracks timing for each step:
- Demo Initialization
- Sample Document Preparation
- Quick Document Import
- Instant Preview Generation
- Export Job Creation
- ML Model Consent Flow
- Real-time Export Progress
- Support Bundle Generation
- Export Completion & Verification
- Demo Summary

### Integration

The demo integrates with:
- `ExportService` for export job management
- `MLConsentComponents` for model consent tracking
- `TimelineComponents` for document timeline creation
- `ExportComponents` for export settings and presets

The demo is self-contained and reproducible, demonstrating all major systems working together without requiring manual setup.
