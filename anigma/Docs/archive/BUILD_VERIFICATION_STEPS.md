# 🎯 Anigma Build Verification - Next Steps

## Step 1: Clean and Build the Project

### Option A: Using Xcode (Recommended for Mac Development)

```bash
# Open your project in Xcode
open anigma.xcodeproj
# or if you're using a workspace:
open anigma.xcworkspace
```

**In Xcode:**
1. Press **⇧⌘K** (Shift + Command + K) to clean the build folder
2. Wait for cleaning to complete
3. Press **⌘B** (Command + B) to build
4. Watch the build output in the Report Navigator (⌘9)

### Option B: Using Command Line

```bash
# Navigate to your project directory
cd /Users/user/Developer/GitHub/Anigma_clean/anigma

# Clean all build artifacts
swift package clean

# Remove resolved dependencies (if needed)
rm -rf .build

# Resolve dependencies fresh
swift package resolve

# Build the entire project
swift build

# Or build with verbose output to see detailed progress:
swift build -v
```

---

## Step 2: Identify Build Status

### ✅ If Build Succeeds:
You'll see output like:
```
Build complete! (XXs)
```

**Action:** Proceed to Step 3 (Run Tests)

### ❌ If Build Fails:
You'll see error messages. **Don't panic!** Follow these sub-steps:

#### 2a. Capture the Error Log
```bash
# Build and save errors to a file
swift build 2>&1 | tee build_output.log

# Or in Xcode:
# Product → Show Build Folder in Finder
# Then check the build logs
```

#### 2b. Categorize the Errors

Look for these patterns:

**Pattern 1: Linker Errors (Duplicate Symbols)**
```
duplicate symbol '_some_function_name' in:
    /path/to/object1.o
    /path/to/object2.o
```
→ This means a C/C++ function is defined in multiple files

**Pattern 2: Swift Compilation Errors**
```
error: cannot find 'TypeName' in scope
error: value of type 'X' has no member 'Y'
```
→ Missing imports or API mismatches

**Pattern 3: Module Not Found**
```
error: no such module 'ModuleName'
```
→ Dependency resolution issue

**Pattern 4: Header Not Found**
```
error: 'header_name.h' file not found
```
→ C/C++ header search path issue

---

## Step 3: Run Tests (If Build Succeeded)

### Run All Tests
```bash
swift test
```

### Run Specific Capsule Tests
```bash
# Test the fixed capsules specifically
swift test --filter CitationExtractionCapsuleTests
swift test --filter TableExtractionCapsuleTests
swift test --filter MathOCRCapsuleTests
swift test --filter LayoutEngineCapsuleTests
swift test --filter AnimationKitTests
```

### In Xcode
1. Press **⌘U** (Command + U) to run all tests
2. Or click the diamond icons next to individual test functions
3. View test results in Test Navigator (⌘6)

---

## Step 4: Verify FFmpeg Dependencies (AnimationKit Specific)

### Check if FFmpeg is Installed
```bash
# Check if FFmpeg libraries are present
ls /opt/homebrew/lib/libavcodec.dylib
ls /opt/homebrew/lib/libavformat.dylib
ls /opt/homebrew/lib/libavutil.dylib
ls /opt/homebrew/lib/libswscale.dylib
ls /opt/homebrew/lib/libswresample.dylib
```

### If Files Not Found:
```bash
# Install FFmpeg via Homebrew
brew install ffmpeg

# Verify installation
brew list ffmpeg
```

### For Intel Macs (if you're on one):
```bash
# Check the alternate path
ls /usr/local/lib/libavcodec.dylib

# If found, you need to update Package.swift:
# Change /opt/homebrew to /usr/local in AnimationNative target
```

---

## Step 5: Verify Tree-sitter Configuration

### Check that lib.c Exists
```bash
ls -la Packages/SyntaxCapsule/Sources/SyntaxNative/src/lib.c
```

**Expected output:**
```
-rw-r--r--  1 user  staff  XXX  lib.c
```

### Verify lib.c Content
```bash
cat Packages/SyntaxCapsule/Sources/SyntaxNative/src/lib.c
```

**Should contain lines like:**
```c
#include "parser.c"
// Possibly other includes for tree-sitter languages
```

### If lib.c is Missing or Empty:
You'll need to create it. Here's a basic template:

```bash
# Create the file
cat > Packages/SyntaxCapsule/Sources/SyntaxNative/src/lib.c << 'EOF'
// Single translation unit for tree-sitter
// This prevents duplicate symbol linker errors

#include "parser.c"

// If you have a scanner (for languages that need it):
// #include "scanner.c"

// Add any additional language-specific source files here
EOF
```

---

## Step 6: Check for Remaining CapsuleError Issues

### Search for Old API Usage
```bash
# Search for deprecated CapsuleError usage
grep -r "CapsuleError.from" Packages/*/Sources/

# Should return no results if fully fixed
```

### Search for Potential Memory Issues
```bash
# Look for direct assumingMemoryBound calls without withUnsafeBytes
grep -r "assumingMemoryBound" Packages/*/Sources/ | grep -v "withUnsafeBytes"

# Review any results to ensure proper memory safety
```

---

## Step 7: Document Your Build Environment

### Create a Build Info File
```bash
cat > BUILD_INFO.md << 'EOF'
# Anigma Build Information

## Environment
- **Xcode Version:** $(xcodebuild -version | head -n1)
- **Swift Version:** $(swift --version)
- **macOS Version:** $(sw_vers -productVersion)
- **Architecture:** $(uname -m)

## Dependencies
- **FFmpeg Path:** $(which ffmpeg)
- **Homebrew Prefix:** $(brew --prefix)

## Build Status
- **Last Successful Build:** $(date)
- **All Tests Passing:** [YES/NO]

## Known Issues
- None

## Special Configuration
- FFmpeg installed via Homebrew at $(brew --prefix ffmpeg)
- Tree-sitter using single translation unit compilation
- CapsuleError API updated to latest version

EOF

# View the file
cat BUILD_INFO.md
```

---

## 🔍 Troubleshooting Quick Reference

### Issue: "Module 'SyntaxNative' not found"
**Solution:**
```bash
# Check Package.swift contains proper target definition
grep -A 5 "name: \"SyntaxNative\"" Package.swift
```

### Issue: "Duplicate symbol errors still appear"
**Solution:**
```bash
# List all .c and .cpp files being compiled
find Packages/SyntaxCapsule/Sources/SyntaxNative -name "*.c" -o -name "*.cpp"

# Verify Package.swift only lists lib.c and syntax_capsule.cpp
grep -A 10 "SyntaxNative" Package.swift | grep "sources"
```

### Issue: "Cannot find type 'TextSegment' in scope"
**Solution:**
```bash
# Check if types are public in LayoutEngineCapsule.swift
grep "public struct TextSegment" Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift
grep "public struct BoundingBox" Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift
```

### Issue: "FFmpeg libraries not found during linking"
**Solution:**
```bash
# Check your Homebrew installation
brew doctor

# Reinstall FFmpeg if needed
brew reinstall ffmpeg

# For Apple Silicon, verify it's using ARM version:
file $(brew --prefix)/lib/libavcodec.dylib
# Should output: Mach-O 64-bit dynamically linked shared library arm64
```

---

## 📊 Expected Timeline

| Step | Time Estimate | Critical? |
|------|--------------|-----------|
| Clean Build | 1-2 minutes | ✅ Yes |
| Full Build | 5-15 minutes | ✅ Yes |
| Run Tests | 2-5 minutes | ⚠️ Important |
| Verify Dependencies | 1 minute | ✅ Yes |
| Documentation | 2 minutes | 💡 Recommended |

**Total Time:** ~10-25 minutes for complete verification

---

## ✅ Success Criteria

You know everything is working when:

1. ✅ `swift build` completes with **0 errors**
2. ✅ `swift test` shows **all tests passing** (or only expected failures)
3. ✅ No duplicate symbol linker errors
4. ✅ No "module not found" errors
5. ✅ AnimationKit can link against FFmpeg libraries
6. ✅ All capsules can find their native dependencies

---

## 🚨 When to Ask for Help

**Stop and report back if you see:**

1. **More than 10 new errors** after building
2. **Errors in modules you didn't modify** (might indicate dependency issues)
3. **Segmentation faults or crashes** during tests
4. **Different errors on consecutive builds** (indicates non-deterministic issues)

**What to share:**
```bash
# Generate a comprehensive error report
echo "=== BUILD ERRORS ===" > error_report.txt
swift build 2>&1 >> error_report.txt
echo "\n=== PACKAGE RESOLVED ===" >> error_report.txt
cat Package.resolved >> error_report.txt
echo "\n=== ENVIRONMENT ===" >> error_report.txt
swift --version >> error_report.txt
xcodebuild -version >> error_report.txt

# Then share error_report.txt
```

---

## 🎉 After Success

Once everything builds and tests pass:

```bash
# Commit your fixes
git add -A
git commit -m "Fix critical build errors

- Fixed SyntaxNative duplicate symbols (259 linker errors)
- Fixed AnimationNative duplicate symbol
- Updated CapsuleError API to latest version
- Made TextSegment and BoundingBox types public
- Excluded Package.swift from ContainerKit compilation
- Added proper header search paths for C++ interop

All targets now build successfully with 0 errors."

# Push to your repository
git push origin main
```

---

## 📚 Reference Documentation

For more details on specific fixes, see:
- [`BUILD_FIXES.md`](BUILD_FIXES.md) - Detailed guide for all errors and warnings
- [`SYNTAXNATIVE_FIX_SUMMARY.md`](SYNTAXNATIVE_FIX_SUMMARY.md) - Tree-sitter specific fixes
- [`GIT_COMMIT_GUIDE.md`](GIT_COMMIT_GUIDE.md) - Best practices for committing changes

---

## 🔄 Quick Command Reference

```bash
# Full clean rebuild sequence
swift package clean && swift package resolve && swift build

# Run specific test suite
swift test --filter "TestSuiteName"

# Check for deprecated API usage
grep -r "CapsuleError.from" Packages/*/Sources/

# Verify FFmpeg installation
ls $(brew --prefix)/lib/libav*.dylib

# Check Swift version
swift --version

# List all build products
ls -la .build/debug/
```

---

**Ready to start?** Begin with **Step 1** and work through sequentially. Good luck! 🚀

---

**Document Version:** 1.0  
**Created:** February 7, 2026  
**Project:** Anigma  
**Purpose:** Post-fix build verification and testing
