# PDFium Vendor for Anigma

PDFium is vendored here as a sidecar-owned native dependency for PDFSidecarExecutable.

## Architecture Rules Compliance

- ✅ PDFium may be vendored only as a sidecar-owned native dependency
- ✅ PDFNative / PDFSidecarNativeShims own PDFium linkage
- ✅ BackendReadiness must not require PDFium
- ✅ BackendReadinessContractTests must not reach PDFNative, PDFSidecarNativeShims, or PDFSidecarExecutable
- ✅ PDFium files must live outside generic SwiftPM source scan paths
- ✅ No PDFium headers/types in contract modules
- ✅ No PDFium in AnigmaPipeline, AnigmaFoundation, or generic runtime targets

## Directory Structure

```
anigma/External/Vendor/PDFium/
├── VERSION                    # PDFium version identifier (145.0.7630.0)
├── SOURCE                     # Source and provenance information
├── CHECKSUMS                  # SHA256 checksums of vendored files
├── LICENSE.pdfium             # Apache 2.0 (official) + MIT (third-party)
├── NOTICE.pdfium              # Attribution notices
├── README.anigma.md           # This file
└── macos-arm64/
    ├── include/               # PDFium C/C++ headers
    │   ├── cpp/               # C++ public API headers
    │   │   ├── fpdf_deleters.h
    │   │   └── fpdf_scopers.h
    │   ├── fpdf_annot.h
    │   ├── fpdf_attachment.h
    │   ├── fpdf_catalog.h
    │   ├── fpdf_dataavail.h
    │   ├── fpdf_doc.h
    │   ├── fpdf_edit.h
    │   ├── fpdf_ext.h
    │   ├── fpdf_flatten.h
    │   ├── fpdf_formfill.h
    │   ├── fpdf_fwlevent.h
    │   ├── fpdf_javascript.h
    │   ├── fpdf_ppo.h
    │   ├── fpdf_progressive.h
    │   ├── fpdf_save.h
    │   ├── fpdf_searchex.h
    │   ├── fpdf_signature.h
    │   ├── fpdf_structtree.h
    │   ├── fpdf_sysfontinfo.h
    │   ├── fpdf_text.h
    │   ├── fpdf_thumbnail.h
    │   ├── fpdf_transformpage.h
    │   └── fpdfview.h
    └── lib/
        └── libpdfium.dylib     # macOS arm64 dynamic library
```

## Usage

- **PDFNative** depends on libpdfium through `.linkedLibrary("pdfium")`
- **PDFSidecarExecutable** depends on PDFNative (transitive dependency)
- **BackendReadinessContractTests** does NOT depend on PDFNative or PDFium

## Binary Provenance

| Aspect | Value |
|--------|-------|
| **Binary Source** | Third-party pre-built from bblanchon/pdfium-binaries |
| **Repository** | https://github.com/bblanchon/pdfium-binaries |
| **Release Tag** | chromium/7630 |
| **Archive** | pdfium-mac-arm64.tgz |
| **Archive SHA256** | e98f2e922cef5acf8b90c91ff681033ff2114ae73e0e3a312462125911b6295c |
| **Binary SHA256** | d94a50092ee59b1b17521b2697018881f352da6f515d7dca01e6aca4319aba14 |
| **Version** | 145.0.7630.0 |
| **Platform** | macOS arm64 (Apple Silicon) |
| **License** | Apache 2.0 (PDFium) + MIT (third-party build) |
| **Official PDFium** | https://pdfium.googlesource.com/pdfium/ (chromium/7630 branch) |

**IMPORTANT:** These are THIRD-PARTY pre-built binaries, NOT official Google/PDFium binaries.
The binaries are built from official PDFium source by Benoit Blanchon and are not
distributed by Google. See LICENSE.pdfium for full license details.

## Paths

| Platform | Architecture | Include Path | Library Path |
|----------|--------------|--------------|--------------|
| macOS | arm64 | $repo/anigma/External/Vendor/PDFium/macos-arm64/include/ | $repo/anigma/External/Vendor/PDFium/macos-arm64/lib/ |

## Version Information

- **PDFium Version:** 145.0.7630.0 (Chromium PDFium branch chromium/7630)
- **Binary Format:** Mach-O 64-bit dynamically linked shared library arm64
- **Symbols:** Verified (FPDF_InitLibrary, FPDF_LoadDocument, FPDF_CloseDocument present)

## Update Policy

1. **Preferred:** Use bblanchon/pdfium-binaries releases matching the target version
2. Check for new PDFium releases quarterly
3. Update CHECKSUMS when updating binaries
4. Verify `swift build --product PDFSidecarExecutable` succeeds after updates
5. Ensure header/binary version match to avoid symbol mismatch
6. For new platforms: Create platform-specific subdirectories (macos-x86_64, linux-x64, windows-x64)

## Provenance Documentation

- **Official PDFium License:** Apache 2.0 (see LICENSE.pdfium)
- **Third-Party License:** MIT (Benoit Blanchon, see LICENSE.pdfium)
- **Source Repository:** https://pdfium.googlesource.com/pdfium/ (official)
- **Binary Repository:** https://github.com/bblanchon/pdfium-binaries (third-party)

## Verification

To verify the vendored binary:

```bash
# Verify archive checksum
shasum -a 256 .build/pdfium-fetch/pdfium-mac-arm64.tgz

# Verify library checksum  
shasum -a 256 anigma/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib

# Verify library type
file anigma/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib

# Verify required symbols
nm -gU anigma/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib | grep "FPDF_InitLibrary"
nm -gU anigma/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib | grep "FPDF_LoadDocument"
nm -gU anigma/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib | grep "FPDF_CloseDocument"
```

## Notes

- This vendoring is specifically for PDFSidecarExecutable and related PDF targets
- PDFium binaries are platform-specific and must match the version of the headers
- The macOS arm64 binary is the primary target for current Anigma development
- Header/binary version mismatch will cause linker errors (undefined symbols)
- Future: Consider adding macos-x86_64, linux-x64, windows-x64 as needed
