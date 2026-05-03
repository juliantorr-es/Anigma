# td-arch-003 - Add architecture tests for runtime authority bypasses

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-governance  
> **Epic**: [p1-runtime-architecture-lockdown](../)  
> **Worktree**: `anigma/`

---

## Goal

Implement comprehensive architecture tests that detect and prevent direct bypasses of runtime authorities (DatabaseAuthority, EvidenceAuthority, PlatformRuntime). These tests will enforce the architectural principle that all operations must route through proper authority boundaries.

## Context

**Problem**: Current architecture allows modules to bypass authority boundaries by directly accessing DatabaseCore, DatabaseActor, or Evidence systems. This violates the Tier 2 authority pattern and creates security/compliance risks.

**Solution**: Create architecture tests that:
1. Detect direct DatabaseCore/DatabaseActor usage
2. Detect direct evidence writes outside EvidenceAuthority
3. Detect PlatformRuntime boundary violations
4. Fail builds when violations are detected
5. Provide clear remediation guidance

**Related Work**:
- **td-arch-001**: Enforced DatabaseAuthority mutation gates (governance checks)
- **td-arch-002**: Unified evidence systems behind EvidenceAuthority (evidence checks)
- **td-arch-003**: Add architecture tests (bypass detection) ← **CURRENT**

## Scope

### In Scope
- ✅ Architecture test framework for authority bypass detection
- ✅ DatabaseCore/DatabaseActor bypass detection
- ✅ Evidence system bypass detection
- ✅ PlatformRuntime boundary violation detection
- ✅ Build-time enforcement (fail CI on violations)
- ✅ Clear error messages with remediation guidance

### Out of Scope
- ❌ Runtime performance optimization
- ❌ New authority implementations
- ❌ Refactoring existing bypasses (separate tasks)

## Acceptance Criteria

⚠️ **PENDING**: Database mutations route through DatabaseAuthority
⚠️ **PENDING**: Evidence recording routes through EvidenceAuthority  
⚠️ **PENDING**: Capability modules cannot directly bypass PlatformRuntime boundaries
⚠️ **PENDING**: Architecture tests catch direct DatabaseCore/DatabaseActor/evidence bypasses

## Implementation Shape

### Architecture Test Framework

```swift
// ArchitectureTestFramework.swift
public struct AuthorityBypassDetector {
    public static func detectDatabaseBypasses(in sourceCode: String) -> [ArchitectureViolation] {
        // Detect direct DatabaseCore/DatabaseActor usage
        let databasePattern = "DatabaseCore\.execute\|\(sql:.*DatabaseActor"
        // Return violations with file/line and remediation
    }
    
    public static func detectEvidenceBypasses(in sourceCode: String) -> [ArchitectureViolation] {
        // Detect direct evidence writes outside EvidenceAuthority
        let evidencePattern = "ReceiptEngine\.record\|CathedralModule\.recordEvidence"
        // Return violations with file/line and remediation
    }
    
    public static func detectPlatformBypasses(in sourceCode: String) -> [ArchitectureViolation] {
        // Detect PlatformRuntime boundary violations
        let platformPattern = "runtime\.database\.execute\|runtime\.evidence\.record"
        // Return violations with file/line and remediation
    }
}

public struct ArchitectureViolation: Error {
    public let file: String
    public let line: Int
    public let violationType: ViolationType
    public let description: String
    public let remediation: String
    
    public enum ViolationType: String {
        case databaseBypass
        case evidenceBypass
        case platformBypass
    }
}
```

### Build Integration

```ruby
# Rakefile / Build Script
task :check_architecture do
  detector = AuthorityBypassDetector.new
  violations = detector.scanSources(
    paths: ["Sources/**/*.swift"],
    exclude: ["Tests/**", "Legacy/**"]
  )
  
  unless violations.empty?
    violations.each { |v| puts "❌ #{v.file}:#{v.line} - #{v.description}" }
    puts "⚠️  Found #{violations.count} architecture violations"
    exit 1 # Fail build
  end
  
  puts "✅ No architecture violations detected"
end
```

### Test Implementation

```swift
// ArchitectureTests.swift
import XCTest
import ArchitectureTestFramework

class AuthorityBypassTests: XCTestCase {
    
    func testDatabaseAuthorityBypassDetection() {
        let source = "DatabaseCore.execute(sql: \"SELECT * FROM users\")"
        let violations = AuthorityBypassDetector.detectDatabaseBypasses(in: source)
        
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations[0].violationType, .databaseBypass)
        XCTAssertTrue(violations[0].remediation.contains("DatabaseAuthority"))
    }
    
    func testEvidenceAuthorityBypassDetection() {
        let source = "ReceiptEngine.shared.recordDecision(action: .test, decision: .allowed)"
        let violations = AuthorityBypassDetector.detectEvidenceBypasses(in: source)
        
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations[0].violationType, .evidenceBypass)
        XCTAssertTrue(violations[0].remediation.contains("EvidenceAuthority"))
    }
    
    func testPlatformRuntimeBypassDetection() {
        let source = "runtime.database.execute(sql: \"DELETE FROM users\")"
        let violations = AuthorityBypassDetector.detectPlatformBypasses(in: source)
        
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations[0].violationType, .platformBypass)
        XCTAssertTrue(violations[0].remediation.contains("PlatformRuntime"))
    }
}
```

## Source Files

- `anigma/Tests/ArchitectureTests/ArchitectureTestFramework.swift` (NEW)
- `anigma/Tests/ArchitectureTests/AuthorityBypassDetector.swift` (NEW)
- `anigma/Tests/ArchitectureTests/ArchitectureViolation.swift` (NEW)
- `anigma/Tests/ArchitectureTests/AuthorityBypassTests.swift` (NEW)
- `anigma/Scripts/check_architecture.rb` (NEW)
- `anigma/Rakefile` (MODIFIED - add architecture check task)

## Validation Commands

```bash
# Run architecture tests
swift test --filter ArchitectureTests

# Check architecture in CI
rake check_architecture

# Manual scan
python3 Scripts/scan_architecture_violations.py Sources/
```

## Proof Requirements

**Proof Artifact**: `Docs/proofs/td-arch-003-architecture-tests-proof.md` (to be created)

### Evidence of Completion:
1. ⚠️ Architecture test framework implemented
2. ⚠️ Database bypass detection working
3. ⚠️ Evidence bypass detection working
4. ⚠️ Platform bypass detection working
5. ⚠️ Build integration complete
6. ⚠️ Test suite passing
7. ⚠️ CI enforcement operational

### Next Steps:
- [ ] Implement architecture test framework
- [ ] Add bypass detection for all authority types
- [ ] Integrate with build system
- [ ] Create proof artifact
- [ ] Move task to "in_progress" status

---

*Task ID: td-arch-003*  
*Created: 2026-05-03*  
*Updated: 2026-05-03*
