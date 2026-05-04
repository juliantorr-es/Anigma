# PDFium Vendoring Research - td-7c0153-01

## Task
Evaluate and implement local PDFium vendoring for PDFSidecarExecutable readiness

## Research Date
2026-05-04

---

## 1. Current Failure Mode

### PDFSidecarExecutable Product Build
- **Command:** `swift build --product PDFSidecarExecutable`
- **Exit Code:** 1 (FAILED)
- **Linker Error:** `ld: library 'pdfium' not found`
- **Linker Warning:** `ld: warning: search path '/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib' not found`

### Exact Error Text
```
error: link command failed with exit code 1 (use -v to see invocation)
ld: warning: search path '/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib' not found
ld: library 'pdfium' not found
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

### PDFSidecarReadiness Status
- **Command:** `Scripts/test_pdf_sidecar_readiness.sh`
- **Exit Code:** 0
- **Warning Count:** 0 (in log output)
- **Class:** PASSED (with warnings)
- **Note:** "Binary may not be linked without PDFium runtime"

### BackendReadinessContractTests Status
- **Command:** `Scripts/test_backend_readiness.sh BackendReadinessContractTests`
- **Exit Code:** 0
- **Warning Count:** 1
- **Class:** CONTAMINATED
- **Source of Contamination:** PDFSidecarExecutable linker error appears in transitive build output

---

## 2. Current PDFium Configuration

### Package.swift Analysis

#### Vendor Library Path Definition
```swift
// anigma/Package.swift:25
let vendorLibPath = "\(packageRoot)/Vendor/lib"

// anigma/Package.swift:26-27
let vendorLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", vendorLibPath])
]
```

#### PDFNative Target Configuration
```swift
// anigma/Package.swift:283-290
.target(
  name: "PDFNative",
  dependencies: ["AnigmaNativeShims"],
  path: "Packages/PDFCapsule/Sources/PDFNative",
  cxxSettings: [
    .headerSearchPath("../../../../Vendor/include")
  ],
  linkerSettings: [.linkedLibrary("pdfium")] + vendorLinkerSettings
)
```

#### PDFSidecarExecutable Target Configuration
```swift
// anigma/Package.swift:1376-1377
.executableTarget(
  name: "PDFSidecarExecutable",
  dependencies: ["PDFSidecarClient", "SidecarPDFService", "PDFNative", "AnigmaNativeShims"],
  path: "Packages/SidecarPDFService/Sources/PDFSidecarExecutable",
  swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
)
```

**Key Finding:** PDFSidecarExecutable depends on PDFNative, which has:
- `.linkedLibrary("pdfium")` - explicitly links the pdfium library
- `vendorLinkerSettings` - search path to `anigma/Vendor/lib`
- C++ header search path to `../../../../Vendor/include`

---

## 3. Current Vendor Directory Structure

### Existing PDFium Files
```
anigma/Vendor/
├── LICENSE
├── VERSION
├── PDFiumConfig.cmake
├── args.gn
└── include/
    ├── fpdf_annot.h
    ├── fpdf_attachment.h
    ├── fpdf_catalog.h
    ├── fpdf_dataavail.h
    ├── fpdf_doc.h
    ├── fpdf_edit.h
    └── ... (20+ PDFium header files)
└── licenses/
    └── pdfium.txt (Apache 2.0 license)
```

### Missing Components
- **`anigma/Vendor/lib/`** - DOES NOT EXIST
- **`libpdfium.dylib` or `libpdfium.a`** - NOT FOUND
- **macOS arm64 binary** - NOT FOUND

### PDFiumConfig.cmake Content
- Version: 145.0.7630.0
- Designed for CMake projects, not SwiftPM
- Expects PDFium library in `lib/` subdirectory
- Platform-specific paths for Windows (dll/lib) and Unix (lib)

---

## 4. Current Search Path Analysis

### Search Path Configuration
- **Hardcoded Path:** `/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib`
- **Path Type:** Absolute, machine-specific
- **Status:** DOES NOT EXIST on current machine
- **Origin:** Derived from `packageRoot` which resolves to absolute path

### Why the Path is Stale
1. The path uses `packageRoot` which is the absolute path to the anigma package
2. This path is machine-specific and not portable
3. The `Vendor/lib` directory does not exist in the repository
4. PDFium binaries have never been vendored in this location

---

## 5. Dependency Graph Analysis

### Target Dependencies
```
BackendReadinessContractTests
└── AnigmaCore
    └── Anigma Foundation
        └── Anigma Primitives
            └── Anigma Native Shims

PDFSidecarExecutable
├── PDFSidecarClient
│   └── Anigma Native Shims
├── SidecarPDFService
│   ├── Anigma Native Shims
│   └── PDF Native
│       └── Anigma Native Shims
└── PDFNative
    └── Anigma Native Shims
```

### Graph Invariants Verification
- **BackendReadinessContractTests → PDFNative:** Edge NOT FOUND ✅
- **BackendReadinessContractTests → PDFSidecarExecutable:** Edge NOT FOUND ✅
- **BackendReadinessContractTests → PDFSidecarNativeShims:** Target NOTFOUND (no such target in Package.swift) ✅

**Key Finding:** There is NO directed reachability between BackendReadinessContractTests and any PDF-related targets. They share `AnigmaNativeShims` as a common dependency, but PDFium linkage is isolated to PDFNative.

### Contamination Risk
- **Source:** `AnigmaNativeShims` carries `vendorLinkerSettings` (search path to Vendor/lib)
- **Risk:** Any target depending on AnigmaNativeShims inherits the stale vendor search path
- **Impact:** BackendReadinessContractTests build includes the linker warning in its transitive build output

---

## 6. Current State of PDFium in Repository

### What Exists
- PDFium C/C++ headers: `anigma/Vendor/include/` (20+ files)
- PDFium CMake config: `anigma/Vendor/PDFiumConfig.cmake`
- PDFium license: `anigma/Vendor/licenses/pdfium.txt` (Apache 2.0)
- PDFium source version: 145.0.7630.0 (from VERSION file)

### What Does NOT Exist
- PDFium library binaries: `anigma/Vendor/lib/libpdfium.*`
- macOS arm64 pre-built library
- Any PDFium binary vendoring
- Checksums or provenance documentation

### PDFSidecarNativeShims Status
- **Directory:** `anigma/Packages/PDFSidecarNativeShims/` EXISTS
- **Files:** C++ source and headers present
- **Package.swift Target:** NOT DEFINED
- **Status:** Orphaned code, not integrated into build

---

## 7. Problem Root Cause

### Primary Issue
The `PDFSidecarExecutable` product cannot link because:
1. `PDFNative` declares `.linkedLibrary("pdfium")` 
2. `PDFNative` linker settings include `vendorLinkerSettings` pointing to `anigma/Vendor/lib`
3. `anigma/Vendor/lib` directory does not exist
4. No PDFium library binary exists at the expected path

### Secondary Issue  
The `BackendReadinessContractTests` shows CONTAMINATED status because:
1. The test harness builds all transitive dependencies
2. PDFSidecarExecutable is built as part of the dependency chain
3. The linker error/warning from PDFSidecarExecutable appears in the output
4. This creates a false positive contamination reading

### Architectural Issue
- `AnigmaNativeShims` is a shared dependency carrying `vendorLinkerSettings`
- This propagates the stale PDFium search path to ALL targets that depend on it
- This is an architectural contamination risk, not actual contamination

---

## 8. Recommended Vendor Layout

### Proposed Structure
```
anigma/External/Vendor/PDFium/
├── VERSION              # Version identifier
├── SOURCE               # Source URL/archive info
├── CHECKSUMS            # SHA256 checksums of binaries
├── LICENSE.pdfium       # Apache 2.0 license text
├── NOTICE.pdfium        # Notices/attributions
├── README.anigma.md     # Anigma-specific usage notes
└── macos-arm64/
    ├── include/         # PDFium headers (symlink or copy)
    │   ├── fpdfview.h
    │   ├── fpdf_doc.h
    │   └── ...
    └── lib/             # PDFium library binaries
        └── libpdfium.dylib (or .a)
```

### Advantages
1. **Isolation:** PDFium files are outside SwiftPM source scan paths
2. **Portability:** Repo-relative paths work across machines
3. **Documentation:** Version, source, checksums, license all documented
4. **Platform-specific:** Separate directories for macos-arm64, macos-x86_64, etc.
5. **No contamination:** BackendReadinessContractTests cannot reach these paths

---

## 9. Decision Options

### Option A: Explicit Vendored Binary Path (RECOMMENDED)

**Approach:**
- Vendor PDFium unter `External/Vendor/PDFium/macos-arm64/`
- Update PDFNative linker settings to use repo-relative path
- Document version, checksum, license, provenance

**Pros:**
- Deterministic builds across all machines with the repo
- No external dependencies required
- Full control over PDFium version
- Consistent with Anigma's vendoring philosophy for sidecar-owned deps
- No system installation required

**Cons:**
- Repository size increases by ~100-200MB (PDFium binary)
- Need to manage updates/maintenance
- Platform-specific binaries for each architecture

**Implementation:**
1. Create `External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib`
2. Create `External/Vendor/PDFium/macos-arm64/include/` (headers)
3. Add metadata files (VERSION, SOURCE, CHECKSUMS, LICENSE, NOTICE, README)
4. Update PDFNative linker settings to point to new path
5. Remove stale `anigma/Vendor/lib` reference

**Path Configuration:**
```swift
// In Package.swift
let pdfiumVendorPath = "\(packageRoot)/../../External/Vendor/PDFium/macos-arm64"
let pdfiumLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", "\(pdfiumVendorPath)/lib"]),
  .unsafeFlags(["-I", "\(pdfiumVendorPath)/include"])
]
```

### Option B: System-Library Target

**Approach:**
- Create a PDFiumSystemLibrary target that expects host-installed PDFium
- Use pkg-config or explicit path discovery
- Sidecar readiness checks for host availability

**Pros:**
- Smaller repository (no vendored binaries)
- System manages PDFium updates
- Easier security updates

**Cons:**
- Requires PDFium installation on all development/CI machines
- Less deterministic (depends on host environment)
- Version drift possible between hosts
- Harder to ensure consistent behavior

**Implementation:**
1. Remove `.linkedLibrary("pdfium")` from PDFNative
2. Add explicit discovery in build script or Package.swift
3. Update PDFSidecarReadiness to check for PDFium availability
4. Classify as ENVIRONMENT_UNAVAILABLE if missing

### Option C: Hybrid (Vendored with System Fallback)

**Approach:**
- Prefer vendored repo-local PDFium if present
- Fall back to host/system discovery
- Explicit readiness classification for each case

**Pros:**
- Flexibility for different environments
- Deterministic when vendored files exist
- Can still use system version if desired

**Cons:**
- Complex logic for fallback
- Two different build configurations to maintain
- Potential for confusion about which is being used

**Implementation:**
1. Create vendored path structure (same as Option A)
2. Add build script to check for vendored files first
3. Fall back to system paths if vendored not found
4. Update PDFSidecarReadiness to report which source is used

---

## 10. Recommendation

**SELECTED: Option A - Explicit Vendored Binary Path**

**Rationale:**
1. **Determinism Priority:** The task specifically requires "deterministic PDFSidecarExecutable product readiness"
2. **Existing Pattern:** Anigma already vendors other native dependencies (FFmpeg headers, etc.)
3. **Sidecar Isolation:** PDFium is explicitly a "sidecar-owned native dependency"
4. **No Contamination:** Vendored files live outside generic SwiftPM source scan paths
5. **Portability:** Repo-relative paths eliminate machine-specific absolute paths

**Decision Confirmation:**
- Deterministic local/CI builds are the priority for this task
- Repository size increase is acceptable for this critical dependency
- Version pinning and checksum documentation provide provenance
- Architecture rules allow PDFium vendoring as sidecar-owned dependency

---

## 11. License/Provenance Requirements

### PDFium License
- **License:** Apache License 2.0
- **Text:** Already present in `anigma/Vendor/licenses/pdfium.txt`
- **Compatibility:** Compatible with Anigma's usage

### Required Documentation Files
```
External/Vendor/PDFium/
├── VERSION              # e.g., "145.0.7630.0"
├── SOURCE               # Download URL, commit hash if from source
├── CHECKSUMS            # SHA256 of each binary file
├── LICENSE.pdfium       # Full Apache 2.0 text
├── NOTICE.pdfium        # Any required notices
└── README.anigma.md     # Usage notes, version policy
```

### Version Information
- **Current Version in Repo:** 145.0.7630.0 (from VERSION file)
- **Recommended:** Use same or newer stable version
- **Source:** Official PDFium releases from https://pdfium.googlesource.com/pdfium/

---

## 12. Proposed Fix

### Step 1: Create Vendor Directory Structure
```bash
mkdir -p External/Vendor/PDFium/macos-arm64/{lib,include}
```

### Step 2: Add PDFium Binaries and Headers
```bash
# Copy existing headers
cp -r anigma/Vendor/include/* External/Vendor/PDFium/macos-arm64/include/

# Add macOS arm64 libpdfium.dylib
# (to be obtained from PDFium build or official distribution)
```

### Step 3: Create Metadata Files
```bash
# VERSION
cat > External/Vendor/PDFium/VERSION << 'EOF'
145.0.7630.0
EOF

# SOURCE  
cat > External/Vendor/PDFium/SOURCE << 'EOF'
Downloaded from: https://pdfium.googlesource.com/pdfium/+archive/refs/tags/chromium/145.0.7630.0.tar.gz
EOF

# CHECKSUMS
# (to be populated after downloading files)

# LICENSE.pdfium
cp anigma/Vendor/licenses/pdfium.txt External/Vendor/PDFium/LICENSE.pdfium

# README.anigma.md
cat > External/Vendor/PDFium/README.anigma.md << 'EOF'
# PDFium Vendor for Anigma

PDFium is vendored here as a sidecar-owned native dependency for PDFSidecarExecutable.

## Usage
- PDFNative depends on libpdfium
- PDFSidecarExecutable depends on PDFNative
- BackendReadinessContractTests does NOT depend on PDFNative

## Paths
- Headers: $repo/External/Vendor/PDFium/macos-arm64/include/
- Library: $repo/External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib

## Update Policy
- Check for new PDFium releases quarterly
- Update CHECKSUMS when updating binaries
- Test PDFSidecarExecutable build after updates
EOF
```

### Step 4: Update Package.swift
```swift
// Replace vendorLibPath reference for PDFNative
let pdfiumMacosArm64Path = "\(packageRoot)/../../External/Vendor/PDFium/macos-arm64"
let pdfiumLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", "\(pdfiumMacosArm64Path)/lib"]),
  .unsafeFlags(["-I", "\(pdfiumMacosArm64Path)/include"])
]

// Update PDFNative target
.target(
  name: "PDFNative",
  dependencies: ["AnigmaNativeShims"],
  path: "Packages/PDFCapsule/Sources/PDFNative",
  cxxSettings: [
    .headerSearchPath("../../../../../../External/Vendor/PDFium/macos-arm64/include")
  ],
  linkerSettings: [.linkedLibrary("pdfium")] + pdfiumLinkerSettings
)
```

### Step 5: Clean Up Stale References
- Remove `anigma/Vendor/lib` from any linker search paths
- Remove stale absolute paths from Package.swift
- Consider removing/moving `anigma/Vendor/` PDFium-related files to new location

---

## 13. Graph Isolation Risks

### Current State
- ✅ No directed path: BackendReadinessContractTests → PDFNative
- ✅ No directed path: BackendReadinessContractTests → PDFSidecarExecutable
- ✅ No PDFSidecarNativeShims target exists in build graph

### After Vendoring
- ✅ PDFium files in `External/Vendor/` are outside SwiftPM source scan paths
- ✅ PDFNative owns PDFium linkage (not AnigmaNativeShims)
- ✅ BackendReadinessContractTests cannot reach PDFNative through dependency graph
- ⚠️ **Risk:** AnigmaNativeShims still carries generic vendorLinkerSettings

### Mitigation for AnigmaNativeShims Risk
The contamination risk via AnigmaNativeShims is a separate architectural issue (td-anigov). For this task:
- Do NOT modify AnigmaNativeShims (per non-goals)
- The vendoring fix eliminates the specific PDFium search path issue
- Generic vendor search path in AnigmaNativeShims is a known issue to be addressed separately

---

## 14. Implementation Priority

1. **HIGH PRIORITY:** Vendor PDFium binary to `External/Vendor/PDFium/macos-arm64/lib/`
2. **HIGH PRIORITY:** Update PDFNative linker settings to use new path
3. **HIGH PRIORITY:** Document version, checksum, license, provenance
4. **MEDIUM PRIORITY:** Update PDFSidecarReadiness to validate PDFium availability
5. **LOW PRIORITY:** Clean up stale `anigma/Vendor/lib` references (out of scope per non-goals)

---

## 15. Next Steps

1. **Acquire PDFium binary** for macOS arm64 (libpdfium.dylib version 145.0.7630.0 or compatible)
2. **Create vendor directory structure** under `External/Vendor/PDFium/`
3. **Generate checksums** for the vendored files
4. **Update Package.swift** with new PDFium paths for PDFNative
5. **Update PDFSidecarReadiness** script to check for PDFium with explicit classification
6. **Validate** the fix meets all acceptance criteria

---

## File References

- Build logs: `.build/td-7c0153-01-pdf-sidecar-readiness-pre.log`
- Build logs: `.build/td-7c0153-01-pdf-sidecar-product-pre.log`
- Build logs: `.build/td-7c0153-01-backend-readiness-pre.log`
- Package: `anigma/Package.swift`
- Vendor: `anigma/Vendor/`
- Graph snapshot: `.build/anigma-graph/`

---

*Status: Research Complete - Ready for Implementation*
*Task: td-7c0153-01*
