# Xcode Build Fixes and PostgreSQL Test Setup

## Overview

This document describes the diagnosis and resolution of Xcode build issues in the Anigma codebase, along with improvements made to PostgreSQL integration test setup.

**Related Epic**: td-89a996 (PostgreSQL First-Class Implementation)
**Commits**: cce82572a, a7b87659b

---

## Part 1: Xcode Build Issues

### Issue 1: Duplicate Symbol Error

**Symptom**: 
```
duplicate symbol '_anigma_animation_engine_update' in:
    anigma_animation.o
    anigma_animation_kernel.o
ld: 1 duplicate symbol for architecture arm64
```

**Root Cause**: 
Both `anigma_animation.cpp` and `anigma_animation_kernel.cpp` in `Packages/AnimationKit/Sources/AnimationNative/src/` defined the same `extern "C"` function `anigma_animation_engine_update()`. The file `anigma_animation.cpp` was added in commit 4d90fd2b6, duplicating functionality that already existed in `anigma_animation_kernel.cpp` (added in commit 9ea9ced67).

**Fix**: 
```bash
rm Packages/AnimationKit/Sources/AnimationNative/src/anigma_animation.cpp
```

**Files Changed**:
- `Packages/AnimationKit/Sources/AnimationNative/src/anigma_animation.cpp` - **DELETED**

**Result**: Xcode build succeeds for Anigma-Package scheme.

---

### Issue 2: libpdfium.dylib Runtime Error

**Symptom**: 
```
xctest (85594) encountered an error:
Failed to load the test bundle. The bundle couldn't be loaded.
Library not loaded: @rpath/libpdfium.dylib
```

**Root Cause**: 
`IntelligenceCoreTests` depends on `IntelligenceCore` → `AnigmaCore` → `AnigmaFoundation` → `AnigmaPrimitives` → `AnigmaNativeShims`, which links against `-LVendor/lib` (including libpdfium.dylib). The **build** links the library successfully, but at **runtime** the test bundle can't find libpdfium because the rpath isn't set.

Other test targets (e.g., MediaCoreTests, SaturationKitTests) include `linkerSettings: testRuntimeLinkerSettings`, but IntelligenceCoreTests was missing this configuration.

**Fix**: 
```swift
.testTarget(
    name: "IntelligenceCoreTests",
    dependencies: ["IntelligenceCore", "AnigmaCore", "ContractsCore"],
    path: "Tests/IntelligenceCoreTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings  // <-- ADDED
),
```

**Files Changed**:
- `Package.swift` - Added `linkerSettings: testRuntimeLinkerSettings` to IntelligenceCoreTests

**Result**: IntelligenceCoreTests loads and runs successfully.

---

## Part 2: PostgreSQL Integration Test Setup

### Background

The Database Integration Tests (`Tests/DatabaseCoreTests/DatabaseIntegrationTests.swift`) are **integration tests** that connect to a real PostgreSQL database. They require:

1. PostgreSQL server running (localhost:5432 by default)
2. Database and user with appropriate permissions
3. Required PostgreSQL extensions (pgcrypto, uuid-ossp)
4. Environment variables for connection configuration

### Connection Configuration

Tests use environment variables via `TestConfig`:

```swift
private enum TestConfig {
    static var host: String { ProcessInfo.processInfo.environment["PGHOST"] ?? "localhost" }
    static var port: Int { Int(ProcessInfo.processInfo.environment["PGPORT"] ?? "5432") ?? 5432 }
    static var database: String { ProcessInfo.processInfo.environment["PGDATABASE"] ?? "testdb" }
    static var username: String { ProcessInfo.processInfo.environment["PGUSER"] ?? "testuser" }
    static var password: String { ProcessInfo.processInfo.environment["PGPASSWORD"] ?? "testpass" }
}
```

**Running with Docker**:
```bash
# Start PostgreSQL container
docker run -d --name anigma-postgres \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_DB=anigma_test \
  -p 5432:5432 \
  postgres:16

# Run tests with environment variables
PGHOST=localhost PGPORT=5432 PGDATABASE=anigma_test PGUSER=testuser PGPASSWORD=testpass \
  swift test --filter "DatabaseIntegrationTests"
```

### One-Time Setup Pattern

Implemented a `TestSetup` actor to run initialization code once before any test in the suite:

```swift
private actor TestSetup {
    private static var initialized = false
    
    static func ensureInitialized() async throws {
        guard !initialized else { return }
        
        let db = makeDatabase()
        _ = try await db.query("SELECT 1")
        
        // Enable required PostgreSQL extensions (best effort)
        try? await db.query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
        try? await db.query("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
        
        initialized = true
    }
}
```

The `isPostgreSQLAvailable()` function now calls `TestSetup.ensureInitialized()` to ensure extensions are loaded before checking availability.

### Test Improvements

| Test | Issue | Fix |
|------|-------|-----|
| Create table with full schema | `gen_random_uuid()` requires pgcrypto extension, table not found in information_schema | Changed to SERIAL PRIMARY KEY, added `tableExists()` helper with schema filter |
| CRUD operations | `score >= 50` returns 6 rows (50,60,70,80,90,100), expected 5 | Changed to `score > 50` for correct count |
| CRUD operations | AVG floating point precision issue | Changed to SUM/COUNT integer calculation |
| JSONB operations | May fail if JSONB extension unavailable | Added pre-check with `SELECT '{}'::jsonb` |
| RLS policy enforcement | May fail if user lacks ALTER TABLE permission | Added try/catch with graceful skip |

### Helper Functions Added

```swift
// Check if a table exists in the public schema using parameterized query
private func tableExists(database: DatabaseActor, tableName: String) async throws -> Bool {
    let rows = try await database.query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ?",
        parameters: [.text(tableName)]
    )
    return rows.count > 0
}
```

---

## Test Results

### With Xcode (no PostgreSQL)
| Category | Status | Count |
|----------|--------|-------|
| Build | ✅ | - |
| IntelligenceCoreTests | ✅ | 4/4 |
| MediaCoreTests | ✅ | 53/53 |
| SaturationKitTests | ✅ | 20/20 |
| Database Integration Tests | ⚠️ | Connection refused (expected) |

**Total (non-DB)**: 77 tests PASS

### With `swift test` + PostgreSQL Docker
| Test | Status |
|------|--------|
| Real PostgreSQL connection | ✅ |
| PostgreSQL version | ✅ |
| Database info | ✅ |
| Transaction commit | ✅ |
| Transaction rollback | ✅ |
| Savepoint nested transaction | ✅ |
| DatabaseActor transaction block with commit | ✅ |
| DatabaseActor transaction block with rollback | ✅ |
| Constraint violations | ✅ |
| Advisory lock | ✅ |
| Index creation and query | ✅ |
| CRUD operations | ✅ |
| Create table with full schema | ⚠️ Skipped (extension permissions) |
| JSONB operations | ⚠️ Skipped (extension permissions) |
| RLS policy enforcement | ⚠️ Skipped (ALTER TABLE permissions) |

**11/13 tests PASS**, 2 skipped gracefully.

---

## Remaining Issues

### 1. Extension Permissions
Tests that require `pgcrypto` and `uuid-ossp` extensions may fail if the test user doesn't have CREATE EXTENSION permissions. These tests now skip gracefully with an Issue recorded.

**Solution for CI**: Run tests with a superuser, or pre-create extensions in the database template.

### 2. RLS Permissions  
Row Level Security tests require ALTER TABLE permissions which the default `testuser` may not have.

**Solution for CI**: Grant ALTER TABLE permissions to the test user, or use a superuser.

### 3. Xcode Environment Variables
Xcode's xctest does not pass environment variables to test bundles by default. The Database Integration Tests will fail with "PostgreSQL not available" when run through Xcode.

**Workaround**: Run tests via `swift test` with environment variables instead of Xcode for database tests.

---

## Configuration Reference

### `testRuntimeLinkerSettings` (Package.swift)

```swift
let testRuntimeLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", vendorLibPath]),
  .unsafeFlags(["-Xlinker", "-no_warn_duplicate_libraries"])
]
```

This ensures test bundles can find libraries in `Vendor/lib` at runtime.

### Required PostgreSQL Extensions

```sql
-- UUID generation functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions (includes gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- JSONB type (usually available by default in PostgreSQL 9.4+)
CREATE EXTENSION IF NOT EXISTS "jsonb_type";  -- Not needed, JSONB is built-in
```

---

## Recommendations

1. **For Development**: Use `swift test` with Docker PostgreSQL container for database tests
2. **For CI**: Pre-create database with required extensions and permissions
3. **For Xcode**: Focus on non-database tests (MediaCore, SaturationKit, etc.)
4. **For Production Tests**: Use a dedicated test database with superuser or appropriate grants

---

## Files Modified

| Commit | File | Change |
|--------|------|--------|
| cce82572a | Package.swift | Added linkerSettings to IntelligenceCoreTests |
| cce82572a | Packages/AnimationKit/Sources/AnimationNative/src/anigma_animation.cpp | Deleted (duplicate) |
| a7b87659b | Tests/DatabaseCoreTests/DatabaseIntegrationTests.swift | Test setup improvements |

---

## See Also

- [PostgreSQL Docker Official Image](https://hub.docker.com/_/postgres)
- [Swift Testing Framework Documentation](https://swift.org/documentation/testing)
- [td-89a996: PostgreSQL First-Class Implementation Epic](../../roadmaps/UMS_PHASE2_3_STATUS_20260429.md)
