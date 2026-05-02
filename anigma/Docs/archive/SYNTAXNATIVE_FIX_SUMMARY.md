# SyntaxNative Build Fix Summary

## Problem

The `SyntaxNative` target was failing to build with duplicate symbol errors:

```
duplicate symbol '_ts_parser_new' in:
    /Users/user/Library/Developer/Xcode/DerivedData/anigma-atnxwkewdwajnidrborjcdedkhsq/Build/Intermediates.noindex/Anigma.build/Debug/SyntaxNative.build/Objects-normal/arm64/lib.o
    /Users/user/Library/Developer/Xcode/DerivedData/anigma-atnxwkewdwajnidrborjcdedkhsq/Build/Intermediates.noindex/Anigma.build/Debug/SyntaxNative.build/Objects-normal/arm64/parser-0cf7b5a65e7b95e56ab91fdd7202e54e.o
duplicate symbol '_ts_parser_reset' in:
    ...
```

## Root Cause

The issue was caused by the `src/lib.c` file in the `SyntaxNative` target. This file is a "library" file that includes all other `.c` files:

```c
// src/lib.c
#include "./alloc.c"
#include "./get_changed_ranges.c"
#include "./language.c"
#include "./lexer.c"
#include "./node.c"
#include "./parser.c"
#include "./point.c"
#include "./query.c"
#include "./stack.c"
#include "./subtree.c"
#include "./tree_cursor.c"
#include "./tree.c"
#include "./wasm_store.c"
```

When Swift Package Manager builds the target:
1. It compiles `lib.c` into `lib.o` (which contains all the included source files)
2. It also compiles each individual `.c` file into separate `.o` files
3. During linking, both `lib.o` and the individual `.o` files are included, causing duplicate symbols

## Solution

Added an `exclude` parameter to the `SyntaxNative` target in `Package.swift` to prevent `lib.c` from being compiled:

```swift
.target(
    name: "SyntaxNative",
    path: "Packages/SyntaxCapsule/Sources/SyntaxNative",
    exclude: ["src/lib.c"],  // <-- Added this line
    publicHeadersPath: "include",
    cxxSettings: [
        .headerSearchPath("include"),
        .headerSearchPath("src")
    ]
),
```

## Why This Works

By excluding `lib.c`, Swift Package Manager will:
1. Compile each `.c` file individually (alloc.c, parser.c, tree.c, etc.)
2. NOT compile `lib.c` (which would create a combined object file)
3. Link all the individual `.o` files without duplication

The `lib.c` file serves as a convenience for creating a combined library in other build systems, but in Swift Package Manager's build system, it causes the duplicate symbol issue.

## Files Modified

- `/Users/user/Developer/GitHub/Anigma_clean/anigma/Package.swift`
  - Added `exclude: ["src/lib.c"]` to the `SyntaxNative` target definition
  - Placed before `publicHeadersPath` to comply with Swift Package Manager parameter ordering requirements

## Verification

Run the test script to verify the fix:

```bash
./test_syntaxnative_fix.sh
```

This script checks:
1. That `lib.c` exists
2. That it's properly excluded in `Package.swift`
3. That the parameter configuration is correct
4. That source files will be compiled individually

## Impact

- **Minimal**: Only affects the `SyntaxNative` target
- **No functional changes**: All source code is still compiled, just not through the `lib.c` intermediary
- **Build time**: May slightly increase (compiling files individually vs. as a single unit)
- **Memory usage**: May slightly increase during build (more object files)

## Alternative Approaches Considered

1. **Delete `lib.c`**: Would break other build systems that might depend on it
2. **Use `sources` parameter**: Would require listing all individual source files explicitly
3. **Exclude approach (chosen)**: Clean, maintainable, and doesn't affect other build systems

## Testing

After applying this fix, the build should complete successfully without duplicate symbol errors for the `SyntaxNative` target.
