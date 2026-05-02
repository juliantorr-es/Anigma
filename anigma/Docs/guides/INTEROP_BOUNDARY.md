# Interop Boundary Standard

## Goal

Ensure native shims and capsule-native targets expose headers consistently so
Swift can import them with @preconcurrency and Cxx interop without fragile
include paths.

## Standard Layout

- Native target root contains an `include/` directory with all public headers.
- Public headers only include other public headers via the module include path.
- Implementation files include public headers directly, not via relative paths.

## Package.swift Pattern

Use the same header exposure pattern for Tier 5 and Tier 3 capsule-native
targets and for `Native/Shims`.

```swift
.target(
    name: "TextPipelineNative",
    path: "Packages/TextPipelineCapsule/Sources/TextPipelineNative",
    publicHeadersPath: "include",
    cSettings: [
        .headerSearchPath("include")
    ],
    cxxSettings: [
        .headerSearchPath("include"),
        // add external header paths here as needed
    ]
)
```

### Required Rules

- Always set `publicHeadersPath: "include"`.
- Always add `.headerSearchPath("include")` in both `cSettings` and
  `cxxSettings`.
- Additional headers (vendors, sibling native targets) use explicit
  `.headerSearchPath` entries, not relative includes.

## Header Include Style

Use the module include path for all public headers.

```cpp
#include "anigma_capsule_core.h"
#include "anigma_text_pipeline_capsule.h"
```

Avoid relative paths such as `../include/...` or `../../Shims/include/...`.

## Swift Interop Pattern

Swift targets consuming native code should import with @preconcurrency and
enable Cxx interop when needed.

```swift
import Foundation
@preconcurrency import TextPipelineNative
```

```swift
swiftSettings: [
    .unsafeFlags(["-strict-concurrency=targeted"]),
    .interoperabilityMode(.Cxx)
]
```

## Checklist

- Native target exports all public headers from `include/`.
- No relative include paths in public headers or C++ sources.
- Swift targets use @preconcurrency for C/C++ modules.
- Tier 5/3 capsule-native targets follow the same layout and settings.
