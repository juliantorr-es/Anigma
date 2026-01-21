# Dependency Boundary Policy

## Structural Separation Requirements

### Core Governance Layer (Immutable Dependencies)
**Targets**: AnigmaCore, DatabaseCore, ContractsCore, HarmoniaCLI, AnigmaASTServicesCore  
**Allowed Dependencies**: Vendored packages only
- `swift-argument-parser` (vendored)
- `swift-syntax` (vendored)

**Forbidden Dependencies**: 
- No external package dependencies beyond vendored ones
- No terminal UI libraries (SwiftTerm, etc.)
- No database libraries (GRDB) - only DatabaseCore may use SQLite directly
- No ML/inference libraries
- No networking libraries

### Capability Layer (Feature-Rich Dependencies)
**Targets**: HarmoniaModule, DiaplasionModule, AccessumModule, etc.  
**Allowed Dependencies**: External packages with version constraints
- `GRDB.swift` (for rich database features)
- `SwiftTerm` (for terminal UX modules only)
- Future capability-specific libraries

## Dependency Conflict Prevention

### Version Range Strategy
- Core governance targets pin to exact versions where possible
- Capability modules use compatible range requirements
- No transitive conflicts allowed across structural boundaries

### Resolution Requirements
```swift
// GOOD: Core depends on vendored, version-locked packages
.package(path: "Tools/Vendor/swift-argument-parser")

// GOOD: Capability uses external packages with ranges
.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")

// BAD: Core governance depending on external packages
// .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
```

### Specific Boundary Rules

#### 1. AST Services Isolation
- `AnigmaASTServicesCore` may import SwiftSyntax types
- Capability modules may import `AnigmaASTServicesCore` 
- Capability modules may NOT import SwiftSyntax directly

#### 2. Database Access Control
- Only `DatabaseCore` may import SQLite directly
- Capability modules may use `DatabaseCore` interfaces
- Capability modules may import `GRDB` for rich features

#### 3. Terminal UX Separation
- `SwiftTerm` may only be used in terminal-specific capability modules
- Core governance CLI (`HarmoniaCLI`) must not depend on SwiftTerm
- Rich CLI features with SwiftTerm go in separate capability modules

## Enforcement Mechanisms

### CI Validation
```bash
# Verify no forbidden dependencies in core targets
./Scripts/verify_dependency_boundaries.sh

# Check for ArgumentParser range conflicts  
swift package show-dependencies | grep "argument-parser" | sort | uniq -c
```

### Static Analysis Rules
1. Import boundary checks (no direct SQLite outside DatabaseCore)
2. Version range validation (prevent conflicting ArgumentParser requirements)
3. Structural dependency verification (core vs capability separation)

### Package.swift Structure
```swift
// MARK: - Core Dependencies (Vendored, Deterministic)
.package(path: "Tools/Vendor/swift-argument-parser"),
.package(path: "Tools/Vendor/swift-syntax"),

// MARK: - Capability Dependencies (External, Versioned)
.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
.package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
```

## Migration Path

### Current State Assessment
- ✅ SwiftTerm declared but unused (no immediate conflict)
- ✅ GRDB properly isolated to capability modules
- ✅ Core governance uses vendored packages only

### Future Safeguards
1. Automated PR checks for boundary violations
2. Dependency impact assessment before adding new packages
3. Regular dependency conflict scanning
4. Structural dependency documentation updates

## Failure Mode Prevention

### Common Anti-Patterns
1. **Capability Leakage**: Adding rich dependencies to core targets
2. **Version Conflicts**: Incompatible ArgumentParser ranges
3. **Import Bleed**: Direct SwiftSyntax imports outside AST services
4. **Database Bypass**: Direct SQLite usage outside DatabaseCore

### Detection & Correction
1. Weekly dependency boundary audits
2. Automated dependency graph analysis
3. Version constraint validation in CI
4. Import boundary enforcement

---

**Policy Purpose**: Ensure stable, predictable core governance that can evolve independently of capability feature dependencies. The core must remain insulated from dependency churn while capability modules can iterate rapidly.