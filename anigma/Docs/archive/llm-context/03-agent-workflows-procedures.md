# Agent Workflows and Operating Procedures

This document defines the standard workflows and operating procedures that AI agents must follow when working with Anigma's two-tier architecture.

## 1. Multi-Agent Pipeline Workflow

### 1.1 Standard Agent Sequence

All multi-agent flows MUST follow this exact sequence:

```
1. Architect → 2. Builder → 3. Validator → 4. Scribe → 5. Tech-Debt Scout
```

**Phase 1: Architect**
- **Responsibility**: Plan and produce structured stub specifications
- **Constraints**: NO file writes, only analysis and planning
- **Output**: Structured specifications in markdown or JSON format
- **Duration**: Analysis and planning only

**Phase 2: Builder**
- **Responsibility**: Implement stubs using existing abstractions and tools
- **Constraints**: Must use existing patterns, run tests
- **Output**: Working implementation with test coverage
- **Duration**: Implementation and testing

**Phase 3: Validator**
- **Responsibility**: Compare implementation vs. spec, check risks and tests
- **Constraints**: Must verify security and governance compliance
- **Output**: Validation report with risk assessment
- **Duration**: Verification and risk analysis

**Phase 4: Scribe**
- **Responsibility**: Update `AGENTS.md`, docs, and `Docs/TechDebt.md`
- **Constraints**: Must reflect all changes accurately
- **Output**: Updated documentation and tracking
- **Duration**: Documentation updates

**Phase 5: Tech-Debt Scout**
- **Responsibility**: Scan for duplication, drift, consolidation work
- **Constraints**: Must record items in `Docs/TechDebt.md`
- **Output**: Tech debt analysis and recommendations
- **Duration**: Ongoing analysis

### 1.2 Agent Handoff Protocol

**Handoff Format:**
```json
{
  "agent": "Architect",
  "phase": 1,
  "status": "complete",
  "output": {
    "specification": "path/to/spec.md",
    "complexity": "medium",
    "estimated_effort": "2-3 hours",
    "security_considerations": ["data_privacy", "access_control"],
    "dependencies": ["AnigmaCore", "DatabaseCore"]
  },
  "next_agent": "Builder",
  "handoff_timestamp": "2025-12-15T10:30:00Z"
}
```

**Validation Requirements:**
- Each phase must complete successfully before handoff
- All outputs must be validated by the next agent
- Failed handoffs must return to previous phase for correction
- All handoffs must be logged in audit trail

## 2. Decision Trees and Checklists

### 2.1 Core Layer Decision Tree

```
┌─────────────────┐
│  Start Task     │
└─────────┬───────┘
          │
    ┌─────▼─────┐
    │Is this    │
    │Core Layer?│
    └─────┬─────┘
          │ Yes         No
    ┌─────▼─────┐ ┌─────▼─────┐
    │Use ONLY   │ │Search     │
    │Harmonia   │ │Existing   │
    │wrapper    │ │Abstractions│
    └─────┬─────┘ └─────┬─────┘
          │              │
    ┌─────▼─────┐ ┌─────▼─────┐
    │Generate   │ │Reuse/Extend│
    │Evidence   │ │Existing    │
    │if needed  │ │Patterns    │
    └─────┬─────┘ └─────┬─────┘
          │              │
          └─────┬────────┘
                │
        ┌───────▼───────┐
        │Document       │
        │Decision       │
        └───────┬───────┘
                │
        ┌───────▼───────┐
        │Update         │
        │TechDebt.md    │
        └───────────────┘
```

### 2.2 Capability Module Decision Tree

```
┌─────────────────┐
│  Need Feature   │
└─────────┬───────┘
          │
    ┌─────▼─────┐
    │Search     │
    │Existing   │
    │Modules    │
└─────┬─────┘
      │
┌─────▼─────┐
│Found      │
│Similar?   │
└─────┬─────┘
      │ Yes    No
┌─────▼─────┐ ┌─────▼─────┐
│Extend     │ │Create New │
│Existing   │ │Module     │
│Module     │ │(with ADR) │
└─────┬─────┘ └─────┬─────┘
      │              │
      └─────┬────────┘
            │
    ┌───────▼───────┐
    │Follow Module  │
    │Development   │
    │Patterns       │
    └───────────────┘
```

### 2.3 Agent Decision Checklist

**Before ANY Action:**
- [ ] Have I read the current `AGENTS.md`?
- [ ] Is this task Core Layer or Capability Module?
- [ ] Have I searched existing abstractions?
- [ ] Do I understand the security implications?
- [ ] Have I identified the correct workflow phase?

**Core Layer Tasks:**
- [ ] Am I using the Harmonia wrapper?
- [ ] Is evidence generation required?
- [ ] Are there security procedures to follow?
- [ ] Have I documented the security implications?

**Capability Module Tasks:**
- [ ] Have I searched for similar components/systems?
- [ ] Can I extend existing patterns?
- [ ] Will this create circular dependencies?
- [ ] Have I followed the module structure?

**Documentation Tasks:**
- [ ] Have I updated `AGENTS.md`?
- [ ] Have I updated `Docs/TechDebt.md`?
- [ ] Have I added proper code comments?
- [ ] Have I created necessary ADRs?

## 3. Common Agent Workflows

### 3.1 Adding New Feature Workflow

**Step 1: Analysis (Architect)**
```bash
# Search existing patterns
rg -t swift "Component|System" Sources/*/Components/
rg -t swift "struct.*:.*Component" Sources/

# Analyze requirements
cat > feature-spec.md << EOF
# Feature Specification

## Requirements
- User story: As a user, I want to...
- Acceptance criteria: ...
- Security considerations: ...
- Performance requirements: ...

## Technical Approach
- Components needed: ...
- Systems needed: ...
- Workflows needed: ...
- Integration points: ...

## Risk Assessment
- Security risks: ...
- Performance risks: ...
- Compatibility risks: ...
EOF
```

**Step 2: Implementation (Builder)**
```bash
# Create components following patterns
cat > Sources/ModuleName/Components/NewFeatureComponent.swift << 'EOF'
import AnigmaCore

public struct NewFeatureComponent: Component, Codable {
    public let property: String
    public let value: Int
    
    public init(property: String, value: Int) {
        self.property = property
        self.value = value
    }
}
EOF

# Create systems
cat > Sources/ModuleName/Systems/NewFeatureSystem.swift << 'EOF'
import AnigmaCore

public struct NewFeatureSystem: System {
    public var name: String { "NewFeature" }
    
    public init() {}
    
    public func update(world: World) async {
        let entities = await world.query(NewFeatureComponent.self)
        for (entity, component) in entities {
            await processFeature(entity: entity, component: component)
        }
    }
}
EOF

# Create tests
cat > Tests/ModuleNameTests/NewFeatureTests.swift << 'EOF'
import XCTest
import AnigmaCore
@testable import ModuleName

class NewFeatureTests: XCTestCase {
    func testComponentSerialization() throws {
        // Test implementation
    }
    
    func testSystemProcessing() async throws {
        // Test implementation
    }
}
EOF

# Run tests
swift test --filter ModuleNameTests
```

**Step 3: Validation (Validator)**
```bash
# Security validation
Anigma/Scripts/harmonia.sh security status

# Integration testing
swift test

# Performance testing
# (Add performance benchmarks as needed)

# Risk assessment
cat > validation-report.md << EOF
# Validation Report

## Security Assessment
- ✅ No Core Layer violations
- ✅ Proper data handling
- ✅ No security vulnerabilities

## Performance Assessment
- ✅ Acceptable performance
- ✅ No memory leaks
- ✅ Efficient queries

## Integration Assessment
- ✅ Proper module boundaries
- ✅ No circular dependencies
- ✅ Correct API usage
EOF
```

**Step 4: Documentation (Scribe)**
```bash
# Update AGENTS.md if needed
# Update module documentation
# Update API documentation

# Update TechDebt.md
echo "- New feature implementation completed" >> Docs/TechDebt.md
```

**Step 5: Tech-Debt Analysis (Scout)**
```bash
# Search for potential duplication
rg -r "NewFeature" Sources/

# Analyze for consolidation opportunities
rg -t swift "Component.*:.*Component" Sources/ | sort | uniq -c

# Report findings
cat > tech-debt-analysis.md << EOF
# Tech Debt Analysis

## Duplications Found
- None

## Consolidation Opportunities
- Consider abstracting common patterns

## Recommendations
- Monitor for similar features
- Consider creating shared utilities
EOF
```

### 3.2 Security Incident Response Workflow

**Step 1: Detection**
```bash
# Check system integrity
Anigma/Scripts/harmonia.sh verify integrity

# Check security status
Anigma/Scripts/harmonia.sh security status

# Review audit logs
Anigma/Scripts/harmonia.sh audit recent
```

**Step 2: Assessment**
```bash
# Generate evidence bundle
anigma-receipt bundle --type security_incident --sign --timestamp

# Verify evidence
anigma-verify ./evidence-bundle/ --strict
```

**Step 3: Response**
```bash
# If key compromise detected
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# Emergency stop if needed
Anigma/Scripts/harmonia.sh emergency stop
```

**Step 4: Recovery**
```bash
# Generate verification bundle for incident period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-15" \
    --include-revoked-keys

# Restore from known-good state
# (Follow recovery procedures)
```

**Step 5: Documentation**
```bash
# Update incident log
echo "$(date): Security incident resolved" >> governance-logbook.md

# Create incident report
cat > Docs/incidents/security-incident-2024-12-15.md << EOF
# Security Incident Report

## Timeline
- Detection: 2024-12-15 10:30 UTC
- Response: 2024-12-15 10:45 UTC
- Resolution: 2024-12-15 11:30 UTC

## Impact
- Systems affected: ...
- Data compromised: ...
- Users affected: ...

## Actions Taken
- Key revocation: ...
- System restart: ...
- Evidence generation: ...

## Lessons Learned
- ...
EOF
```

### 3.3 Module Maintenance Workflow

**Step 1: Health Check**
```bash
# Check module compilation
swift build --target ModuleName

# Run module tests
swift test --filter ModuleNameTests

# Check for deprecated patterns
rg -t swift "deprecated|TODO|FIXME" Sources/ModuleName/
```

**Step 2: Dependency Update**
```bash
# Check for outdated dependencies
swift package update

# Test with updated dependencies
swift test

# Verify integration
Anigma/Scripts/harmonia.sh trust bounds
```

**Step 3: Performance Analysis**
```bash
# Run performance benchmarks
# (Add specific benchmark commands)

# Analyze memory usage
# (Add memory profiling commands)

# Check for inefficient queries
rg -t swift "world\.query\(" Sources/ModuleName/
```

**Step 4: Documentation Update**
```bash
# Update API documentation
# Update module README
# Update examples

# Check for undocumented changes
git diff --name-only HEAD~1 | xargs grep -l "public.*func"
```

## 4. Error Handling and Recovery

### 4.1 Common Error Scenarios

**Build Errors:**
```bash
# Check compilation errors
swift build 2>&1 | grep "error:"

# Fix common issues
# - Check imports
# - Verify syntax
# - Check dependencies
```

**Test Failures:**
```bash
# Run specific failing test
swift test --filter TestName

# Debug test failure
# - Check test setup
# - Verify mock data
# - Check assertions
```

**Integration Issues:**
```bash
# Verify Core Layer integration
Anigma/Scripts/harmonia.sh trust bounds

# Check module registration
# - Verify register() function
# - Check system registration
# - Validate workflow definitions
```

### 4.2 Recovery Procedures

**Partial Failure Recovery:**
```bash
# Identify failed component
git status
git diff

# Reset to known-good state
git checkout -- Sources/ModuleName/

# Reapply changes incrementally
# Test each change
```

**Complete Failure Recovery:**
```bash
# Reset to last known-good commit
git log --oneline -10
git checkout <known-good-commit>

# Rebuild from scratch
rm -rf .build
swift build

# Verify system integrity
Anigma/Scripts/harmonia.sh verify integrity
```

## 5. Communication and Coordination

### 5.1 Inter-Agent Communication

**Status Updates:**
```json
{
  "agent": "Builder",
  "phase": 2,
  "status": "in_progress",
  "progress": 0.6,
  "blockers": [],
  "estimated_completion": "2024-12-15T12:00:00Z"
}
```

**Handoff Requests:**
```json
{
  "agent": "Builder",
  "phase": 2,
  "status": "complete",
  "output": {
    "implementation": "complete",
    "tests": "passing",
    "integration": "verified"
  },
  "next_agent": "Validator",
  "handoff_timestamp": "2024-12-15T11:30:00Z"
}
```

### 5.2 Escalation Procedures

**Technical Escalation:**
```bash
# Document technical issue
echo "$(date): Technical escalation - $(issue description)" >> escalation-log.md

# Request expert review
# (Follow escalation protocol)
```

**Security Escalation:**
```bash
# Immediate security response
Anigma/Scripts/harmonia.sh emergency stop

# Document security issue
echo "$(date): Security escalation - $(issue description)" >> security-log.md

# Follow security incident response
```

Following these workflows ensures consistent, secure, and maintainable development across Anigma's two-tier architecture while maintaining proper governance and audit trails.