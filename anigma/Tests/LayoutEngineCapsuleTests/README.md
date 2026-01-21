# LayoutEngineCapsuleTests

Comprehensive test suite for the LayoutEngineCapsule module.

## Test Categories

1. **Basic Functionality**
   - Wrapper initialization
   - Configuration validation
   - Empty PDF handling

2. **Text Extraction**
   - Simple text PDF generation and extraction
   - Font and color detection (if available)

3. **Table Detection**
   - Tables with visible borders
   - Inferred tables (text alignment)
   - Merged cells
   - Table bounding box detection

4. **Figure/Image Detection**
   - Image placeholder detection
   - Bounding box accuracy

5. **Spatial Index Queries**
   - Spatial index creation
   - Bounding box queries
   - Result validation

6. **Error Handling**
   - Invalid PDF data
   - Malformed PDFs
   - Edge cases

7. **Configuration Testing**
   - Determinism tiers
   - Confidence thresholds
   - Merge text thresholds

8. **Performance & Memory**
   - Large PDF processing
   - Memory leak detection
   - Repeated operations

## Running Tests

```bash
# Run all tests
swift test --filter LayoutEngineCapsuleTests

# Run specific test
swift test --filter LayoutEngineCapsuleTests/testSimpleTextPDF

# Generate test coverage
swift test --filter LayoutEngineCapsuleTests --enable-code-coverage
```

## Test Resources

- `TestResources/sample.pdf`: Existing sample PDF from the codebase
- Generated PDFs: Created on-the-fly using `SimplePDFGenerator`

## Adding New Tests

1. Add test methods to `LayoutEngineCapsuleTests.swift`
2. Use existing helper methods or extend `SimplePDFGenerator`
3. For new PDF types, add generation methods to `SimplePDFGenerator`
4. Include test resources in `TestResources/` if needed

## Notes

- The test suite is designed to be deterministic and reproducible
- PDF generation uses simple PDF format construction (no external libraries)
- Some tests may be skipped if the underlying capsule doesn't support certain features
- Performance tests are marked with `measure` block