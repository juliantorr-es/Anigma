# DSPS Console

Staff portal for DSPS alt-media review and correction.

## Purpose

Web UI for DSPS staff to:
- Review documents processed by Anigma
- Correct OCR errors
- Add/edit alt-text for images
- Verify document structure (headings, lists, tables)
- Approve or reject processed files
- View student request queue

## Stack

| Library | License | Purpose |
|---------|---------|---------|
| React 18 | MIT | UI framework |
| Tailwind CSS | MIT | Styling |
| TipTap | MIT | Rich text editing for corrections |
| PDF.js | Apache 2.0 | Document preview |
| Radix UI | MIT | Accessible primitives |
| React Query | MIT | Data fetching |

## Build

```bash
npm install
npm run build
```

## Features

### Request Queue
- List of pending alt-media requests
- Filter by student, course, priority, status
- Bulk actions (approve, assign, prioritize)

### Document Review
- Side-by-side: original PDF + OCR text
- Click-to-edit OCR corrections
- Highlight problem areas
- Alt-text editor for images

### Structure Editor
- Heading level assignment
- List detection correction
- Table structure editing
- Reading order adjustment

### Quality Dashboard
- Processing success rates
- Average turnaround time
- Staff workload distribution
- Error pattern analysis

## API Contract

```
GET  /api/requests           # Student requests
GET  /api/requests/:id       # Request details
GET  /api/documents/:id      # Document with OCR
PATCH /api/documents/:id     # Submit corrections
GET  /api/documents/:id/pdf  # Original PDF file
POST /api/requests/:id/approve
POST /api/requests/:id/reject
```

## File Structure

```
src/
├── main.tsx
├── App.tsx
├── components/
│   ├── DocumentViewer.tsx    # PDF.js wrapper
│   ├── TextEditor.tsx        # TipTap for OCR correction
│   ├── AltTextEditor.tsx     # Image alt-text entry
│   ├── StructureEditor.tsx   # Heading/list/table editing
│   └── RequestQueue.tsx      # Queue management
├── pages/
│   ├── Queue.tsx
│   ├── Review.tsx
│   └── Dashboard.tsx
└── api/
```

## Accessibility

This tool is for DSPS staff who work with accessibility every day.
The UI itself must be fully accessible:
- Keyboard navigable
- Screen reader compatible
- High contrast support
- Focus indicators
- ARIA labels everywhere
