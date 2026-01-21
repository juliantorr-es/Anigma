# Job Kinds Registry

This directory contains the canonical registry of supported job kinds.

## Structure

Each job kind is defined in a separate file with:
- **Kind string**: e.g., `pdf.render_page`
- **Config schema**: CBOR/JSON schema for deterministic config
- **Input requirements**: Expected artifact types
- **Output specification**: What artifacts are produced
- **Toolchain requirements**: Which tools must be available
- **Normalization rules**: How to canonicalize config for hashing

## Job Kind Categories

### PDF Operations
- `pdf.render_page` - Render specific page to image
- `pdf.extract_text` - Extract text content
- `pdf.normalize` - Normalize PDF structure
- `pdf.ocr` - OCR scanned pages
- `pdf.repair` - Repair corrupted PDF
- `pdf.linearize` - Optimize for web streaming

### Document Conversion
- `doc.convert` - Convert between formats (Pandoc)
- `doc.extract_structure` - Extract document structure
- `doc.to_markdown` - Convert to Markdown
- `doc.to_docx` - Convert to DOCX
- `doc.to_epub` - Convert to EPUB

### Video Operations
- `video.transcode` - Transcode video
- `video.proxy` - Generate proxy/preview
- `video.thumbnails` - Extract thumbnail images
- `video.extract_audio` - Extract audio track
- `video.burn_subtitles` - Burn subtitles into video

### Audio Operations
- `audio.normalize` - Normalize audio levels
- `audio.resample` - Resample to different rate
- `audio.transcode` - Transcode audio format

### Image Operations
- `img.convert` - Convert image format
- `img.normalize` - Normalize image
- `img.thumbnail` - Generate thumbnail
- `img.ocr_region` - OCR specific region
- `img.compress` - Compress image

### Vector Operations
- `vector.convert` - Convert vector format
- `vector.rasterize` - Rasterize to bitmap
- `vector.trace` - Trace bitmap to vector

### LaTeX Operations
- `latex.build` - Compile LaTeX document
- `latex.preview_pages` - Generate page previews
- `latex.extract_citations` - Extract bibliography

### ML Operations
- `ml.embed` - Generate embeddings
- `ml.classify` - Classify content
- `ml.transcribe` - Transcribe audio
- `ml.search_index_build` - Build search index

## Adding New Job Kinds

1. Create `<category>.<operation>.yaml` in this directory
2. Define schema following template
3. Update daemon job dispatcher
4. Add tests for determinism
5. Document in `Docs/sidecar/job-kinds.md`
