# Phase 3 Bundle Identifier Fix

## Problem
SwiftPM executables don't have bundle identifiers by default. The app was failing when trying to index because certain macOS APIs require a proper bundle identifier.

Error seen:
```
Cannot index window tabs due to missing main bundle identifier
```

## Solution
Created proper .app bundle with Info.plist containing:
- `CFBundleIdentifier`: `com.anigma.prototype`
- `CFBundleName`: `Anigma`
- Other required macOS app metadata

## Implementation

**Files created:**
- `anigma/Sources/AnigmaAppMac/Info.plist` - Bundle metadata
- `build_app_bundle.sh` - Script to wrap executable in .app bundle

**Files modified:**
- `anigma/Package.swift` - Added Info.plist as resource (excluded from build)
- `run_prototype.sh` - Updated to build and launch .app bundle

**Build process:**
1. SwiftPM builds the executable: `anigma-app`
2. `build_app_bundle.sh` creates `.build/debug/AnigmaPrototype.app` structure
3. Copies executable to `Contents/MacOS/AnigmaPrototype`
4. Copies `Info.plist` to `Contents/Info.plist`

**Launch:**
```bash
./run_prototype.sh
# helper only:
./build_app_bundle.sh
open anigma/.build/debug/AnigmaPrototype.app
```

## Verification

```bash
# Check bundle identifier
defaults read "$PWD/anigma/.build/debug/AnigmaPrototype.app/Contents/Info" CFBundleIdentifier
# Output: com.anigma.prototype

# Verify app launches
ps aux | grep AnigmaPrototype
```

## Notes

- The app must be launched via the .app bundle, not the raw executable
- Running the raw executable will still work but won't have bundle identifier
- Xcode scheme still builds the executable; use `run_prototype.sh` to build and launch the .app
- For distribution, this would be replaced with proper Xcode project or xcodebuild

## Status
✅ Fixed - App now has bundle identifier and can use macOS APIs requiring it
✅ App launches successfully with proper bundle
✅ Indexing should work (to be verified in smoke test)
