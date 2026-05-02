# Swift 6.2 and Interoperability: The Definitive Guide

**Date**: February 2026
**Version**: Swift 6.2 (Strict Concurrency Enabled)
**Target**: Apple Silicon (macOS 15+, iOS 18+)

## 1. Strict Concurrency & The Swift 6 Migration

Swift 6.2 enforces data-race safety at compile time. This is not optional for new projects and requires a shift in architectural thinking.

### The "Data Race Safety" Model
Swift's concurrency model relies on **Isolation Domains**:
- **MainActor**: Isolated to the main thread (UI).
- **Actors**: Isolated to their own serial executor.
- **Tasks**: Units of asynchronous work that inherit or establish isolation.
- **Sendable**: The thread-safety passport. A type is `Sendable` if it can be safely passed between isolation domains.

### Migration Phases (The "Staged" Approach)

1.  **Phase 1: Targeted Checking**
    Set build setting `SWIFT_STRICT_CONCURRENCY = targeted`.
    - Shows warnings only for explicit `async` code and `Sendable` violations in exposed APIs.
    - **Action**: Fix explicit `Sendable` violations in your public structs/classes.

2.  **Phase 2: Complete Checking**
    Set `SWIFT_STRICT_CONCURRENCY = complete`.
    - Shows warnings for *all* potential data races, even in non-async code.
    - **Action**: This is where you address global state.
    - **Fixing Globals**:
        ```swift
        // BAD
        var globalCache: [String: String] = [:]

        // GOOD (Option A: Global Actor)
        @MainActor var globalCache: [String: String] = [:]

        // GOOD (Option B: Actor)
        actor CacheService {
            private var cache: [String: String] = [:]
            func get(_ key: String) -> String? { cache[key] }
        }
        ```

3.  **Phase 3: Swift 6 Language Mode**
    Set `SWIFT_VERSION = 6.0`.
    - All warnings become **Errors**. Code will not compile until safe.

### Common Migration Patterns

#### The `@unchecked Sendable` Escape Hatch
Use this *only* when you are interfacing with C code or using internal locks (like `OSAllocatedUnfairLock`) that the compiler cannot see.

```swift
// A thread-safe class using an internal lock, but compiler doesn't know it.
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    func update(_ key: String, value: Any) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }
}
```

#### `nonisolated` Keyword
Use this to exempt specific methods in an actor from isolation, usually because they access immutable state.

```swift
actor UserStore {
    let id: UUID // Immutable, so safe to read from anywhere
    var username: String

    nonisolated func getID() -> UUID {
        return id // No await needed!
    }
}
```

#### Preconcurrency Imports
If a dependency (e.g., an old library) isn't updated for Swift 6, import it with `@preconcurrency` to suppress warnings at the boundary.

```swift
@preconcurrency import OldFramework
```

## 2. Advanced C++ Interoperability

Swift 6.2 allows direct consumption of C++ APIs without Objective-C wrappers.

### Configuration
In `Package.swift`:
```swift
.target(
    name: "MySwiftTarget",
    dependencies: ["MyCxxTarget"],
    swiftSettings: [.interoperabilityMode(.Cxx)]
)
```

### Mapping Complex Types

#### `std::vector` -> `CxxVector`
Behaves like a Swift `RandomAccessCollection`.
```swift
// C++: std::vector<int> getScores();
let vector = myCxxService.getScores()
for score in vector { // Iteration works naturally
    print(score)
}
```

#### `std::map` -> `CxxDictionary`
Iterating gives you key-value pairs.
```swift
// C++: std::map<std::string, int> getInventory();
let inventory = myCxxService.getInventory()
if let count = inventory["Sword"] { // Subscript works
    print(count)
}
```

### Memory Management & Safety
- **Reference Counting**: Swift can manage C++ `std::shared_ptr` if the C++ type is annotated with `SWIFT_SHARED_REFERENCE`.
- **Value Types**: C++ structs are imported as value types. Swift calls the C++ copy constructor when copying.
- **Unsafe References**: Raw C++ pointers (`MyClass*`) come into Swift as `UnsafeMutablePointer<MyClass>`. You are responsible for safety.

## 3. Embedded Swift (New in 6.0+)

Target restricted environments (Firmware, Kernels, Playdate console).
- **Disables**: Reflection (Mirror), runtime metadata (mostly), and heap allocation (optional).
- **Enables**: Using Swift syntax in places where only C was previously viable.
- **Flag**: `-enable-experimental-feature Embedded`

```swift
// Embedded Swift Example
@_cdecl("main")
func main() {
    let x = 42
    // No print() (requires stdlib), use platform specific UART/Serial putc
}
```
