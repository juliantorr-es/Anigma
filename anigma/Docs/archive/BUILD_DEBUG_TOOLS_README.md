# Anigma Build Debugging Tools

Complete suite of tools to capture, analyze, and fix build errors in the Anigma project.

## Quick Start

### One Command to Rule Them All

```bash
bash debug_build.sh
```

This master script will:
1. ✅ Capture all build errors with context
2. 🔍 Analyze and categorize errors
3. 💡 Generate fix suggestions
4. 📊 Show statistics and next steps

## Individual Tools

### 1. Capture Build Errors

Captures raw build output and creates a structured report:

```bash
bash capture_build_errors.sh
```

**Outputs:**
- `build_errors_raw.txt` - Complete compiler output
- `build_errors_report.txt` - Grouped and formatted errors
- `build_errors_summary.json` - JSON summary for scripts

### 2. Advanced Analysis (Python)

Performs sophisticated error pattern analysis:

```bash
python3 analyze_build_errors.py build_errors_raw.txt
```

**Features:**
- Error classification by pattern
- Frequency analysis
- File impact ranking
- Intelligent fix suggestions

**Outputs:**
- `build_errors_analysis.txt` - Detailed analysis report
- `build_errors_analysis.json` - Structured data

**Requirements:** Python 3.6+

### 3. Fix Suggestions

Generates actionable fix suggestions:

```bash
bash suggest_fixes.sh
```

**Outputs:**
- `suggested_fixes.md` - Markdown document with:
  - Quick actions for each error type
  - Code examples
  - Find/replace commands
  - Priority order

## Workflow

### Initial Diagnosis

```bash
# Run complete analysis
bash debug_build.sh

# Review output files
cat suggested_fixes.md
```

### Fix Iteration Loop

```bash
# 1. Make fixes based on suggestions
# 2. Re-run build capture
bash capture_build_errors.sh

# 3. Check progress
grep -c "error:" build_errors_raw.txt

# 4. Repeat until error count is 0
```

### Quick Error Count

```bash
# Check current error count without full rebuild
grep -c "error:" build_errors_raw.txt
```

## Common Error Types & Fixes

### Type Ambiguity

**Problem:**
```
error: ambiguous use of 'PipelineStage'
```

**Fix:**
```swift
// Use fully qualified name
func createPipeline(name: String, stages: [AnigmaHostMac.PipelineStage]) async
```

**Or create a typealias:**
```swift
// TypeAliases.swift
typealias PipelineStage = AnigmaHostMac.PipelineStage
```

### Missing Members

**Problem:**
```
error: value of type 'ModelRegistryEntry' has no member 'spec'
```

**Fix:** Check module documentation for API changes
```swift
// Old API
let spec = entry.spec

// New API (example)
let taskKind = entry.taskKind
let format = entry.backendFormat
```

### Cannot Find Type

**Problem:**
```
error: cannot find type 'SomeType' in scope
```

**Fix:** Add missing import
```swift
import ModuleName
```

### Argument Mismatch

**Problem:**
```
error: missing argument for parameter 'newParam' in call
```

**Fix:** Update function call to match new signature
```swift
// Check the function definition in the module
// Update call site with new parameters
```

## Output Files Reference

| File | Description | Use Case |
|------|-------------|----------|
| `build_errors_raw.txt` | Raw compiler output | Grep for specific errors |
| `build_errors_report.txt` | Grouped errors | Human reading |
| `build_errors_summary.json` | JSON summary | Scripting |
| `build_errors_analysis.txt` | Advanced analysis | Deep dive |
| `build_errors_analysis.json` | Detailed JSON | Programmatic access |
| `suggested_fixes.md` | Fix guide | Action plan |

## Tips & Tricks

### Batch Find & Replace

Fix all occurrences of an ambiguous type:

```bash
# Example: Replace PipelineStage with qualified name
find Sources/AnigmaAppMac -name "*.swift" \
  -exec sed -i '' 's/\([^.]\)PipelineStage/\1AnigmaHostMac.PipelineStage/g' {} \;
```

### Focus on High-Impact Files

```bash
# Find files with most errors
grep "error:" build_errors_raw.txt | \
  sed -E 's/^([^:]+):.*$/\1/' | \
  sort | uniq -c | sort -rn | head -10
```

### Watch Error Count Decrease

```bash
# Before fixes
ERROR_BEFORE=$(grep -c "error:" build_errors_raw.txt)

# Make your fixes...

# After fixes
bash capture_build_errors.sh
ERROR_AFTER=$(grep -c "error:" build_errors_raw.txt)

echo "Progress: $ERROR_BEFORE → $ERROR_AFTER errors"
```

### Filter Errors by Type

```bash
# Show only ambiguous type errors
grep "ambiguous use of" build_errors_raw.txt

# Show only missing member errors
grep "has no member" build_errors_raw.txt
```

## Known Issues (from BINARY_BUNDLE_COMPLETE.md)

1. **PipelineStage** - Defined in multiple modules
   - ✅ **Fixed** in `PipelineStore.swift`
   
2. **Model Registry API** - Changed from `ModelSpec` to `ModelRegistryEntry`
   - Need to update call sites in AppStore.swift
   
3. **RunSpec** - Initializer parameters changed
   - Check ContractsCore for new signature

## Integration with Existing Docs

These tools complement existing documentation:

- `BINARY_BUNDLE_COMPLETE.md` - Lists known issues
- `build_mac_app.sh` - Builds app bundle after fixes
- `Scripts/` - Additional build automation

## Troubleshooting

### "Command not found: python3"

The Python analysis is optional. Basic bash tools will still work:

```bash
# Skip Python, use bash only
bash capture_build_errors.sh
bash suggest_fixes.sh
```

### "Permission denied"

Make scripts executable:

```bash
chmod +x debug_build.sh capture_build_errors.sh suggest_fixes.sh
```

### "No such file or directory"

Run from project root:

```bash
cd /path/to/anigma
bash debug_build.sh
```

## Next Steps After Zero Errors

Once all compilation errors are fixed:

```bash
# Test the build
swift build --product anigma-app

# Create full app bundle
bash build_mac_app.sh

# Test the app
open .build/release/Anigma.app
```

## Support

If you encounter issues with these tools:

1. Check you're in the project root directory
2. Verify Swift toolchain is installed: `swift --version`
3. Ensure all dependencies are resolved: `swift package resolve`

---

**Last Updated:** 2026-02-06  
**Maintainer:** Anigma Build Team
