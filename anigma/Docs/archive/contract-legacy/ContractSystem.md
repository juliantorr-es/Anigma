# Anigma Contract System

> **Contracts are not documentation—they are executable law.**

## Overview

The Anigma Contract System transforms abstract design principles into **mechanically enforceable rules** that govern every aspect of the application. Unlike traditional style guides or best practices documents, these contracts are **verified automatically** on every commit and **block merges** when violated.

## Philosophy

### Traditional Approach (Broken)
```
Design Principles → Documentation → Hope developers read it → Drift
```

### Contract Approach (Working)
```
Design Principles → Executable Contracts → CI Enforcement → Guaranteed Compliance
```

## Contract Categories

### 1. System Contracts
**Purpose**: Ensure architectural integrity and operational reliability

- **OperationResult Contract** ([Ticket 001](../Tickets/001_operation_result_pdf_import.md))
  - All async operations use `OperationResult<T>` envelope
  - Progress reporting for operations > 200ms
  - Structured error schema with stable codes
  - State transition validation

- **Performance Contract** ([Ticket 006](../Tickets/006_performance_contract.md))
  - Hard latency budgets (e.g., PDF import: 200ms/page)
  - Memory limits per operation
  - Throughput constraints
  - Benchmark suite in CI

- **Accessibility Contract** ([Ticket 002](../Tickets/002_accessibility_contract.md))
  - WCAG 2.1 AA compliance
  - All interactive elements have labels
  - Keyboard navigation support
  - VoiceOver compatibility

### 2. UI/UX Contracts
**Purpose**: Ensure consistent, high-quality user experience

- **Legibility & Hierarchy** ([Ticket 007](../Tickets/007_legibility_hierarchy_contract.md))
  - Standardized typography (Inter for body, Roboto for titles)
  - Semantic font usage
  - Accessible heading structures

- **Color Contract** ([Ticket 009](../Tickets/009_color_contract.md))
  - Semantic color palette only
  - No hardcoded `Color.red`, `Color.blue`, etc.
  - High-contrast mode support
  - Colorblind accessibility

- **Alignment Contract** ([Ticket 010](../Tickets/010_alignment_contract.md))
  - 12-column grid system
  - Consistent spacing via `Bauhaus.Grid`
  - Anatomical layouts (predictable component placement)

- **Affordance Contract** ([Ticket 011](../Tickets/011_affordance_contract.md))
  - Clear visual states (default, hover, active, disabled, focus)
  - Instant feedback (<100ms) for all interactions
  - Standardized button styles

- **Aesthetic-Usability** ([Ticket 008](../Tickets/008_aesthetic_usability_contract.md))
  - Premium polish and micro-interactions
  - Smooth transitions (60fps)
  - Glassmorphism and modern aesthetics

## Enforcement Mechanisms

### 1. CI Gates (Automated)
```bash
# Run on every PR
./Scripts/ci/check-accessibility.sh
./Scripts/ci/check-design-tokens.sh
./Scripts/ci/check-performance-budgets.sh
./Scripts/ci/check-type-authority.sh
```

**GitHub Actions**: [`.github/workflows/contract-enforcement.yml`](../.github/workflows/contract-enforcement.yml)

### 2. Test Suite (Compile-Time)
```swift
// XCTest+Contracts.swift
func assertOperationValid<T>(
    _ result: OperationResult<T>,
    expectedKind: String
)
```

**Performance Benchmarks**: [`PerformanceBenchmarkTests.swift`](../Tests/AnigmaAppMacTests/PerformanceBenchmarkTests.swift)

### 3. Design System (Runtime)
```swift
// Bauhaus Design Tokens
Bauhaus.Color.accent      // ✅ Semantic
Bauhaus.Font.header       // ✅ Semantic
Bauhaus.Grid.x2           // ✅ Semantic

Color.red                 // ❌ Hardcoded
.font(.system(size: 14))  // ❌ Hardcoded
.padding(16)              // ❌ Magic number
```

## Current Status

### Contract Compliance
| Contract | Status | Coverage | Violations |
|----------|--------|----------|------------|
| Type Authority | ✅ PASSING | 100% | 0 |
| Design Tokens | ❌ FAILING | 84% | 26 |
| Accessibility | ⏳ READY | TBD | TBD |
| Performance | ⏳ READY | TBD | TBD |

**Full Status**: [ContractEnforcementStatus.md](ContractEnforcementStatus.md)

### Known Violations
- **16 hardcoded colors** (must use `Bauhaus.Color`)
- **10 hardcoded fonts** (must use `Bauhaus.Font`)
- **54 hardcoded spacing values** (should use `Bauhaus.Grid`)
- **44 unstyled buttons** (should use `.primaryButtonStyle()`)

## How to Use

### For Developers

#### 1. Before Committing
```bash
# Run contract checks locally
./Scripts/ci/check-design-tokens.sh
./Scripts/ci/check-accessibility.sh
```

#### 2. Fixing Violations
```swift
// ❌ Before (violates Color Contract)
Text("Error").foregroundColor(.red)

// ✅ After (compliant)
Text("Error").foregroundColor(Bauhaus.Color.error)
```

```swift
// ❌ Before (violates Font Contract)
Text("Title").font(.system(size: 20, weight: .bold))

// ✅ After (compliant)
Text("Title").font(Bauhaus.Font.header)
```

```swift
// ❌ Before (violates Affordance Contract)
Button("Submit") { /* action */ }

// ✅ After (compliant)
Button("Submit") { /* action */ }
    .primaryButtonStyle()
```

#### 3. Writing New Code
1. **Check the contract**: Review relevant ticket (e.g., Ticket 009 for colors)
2. **Use design tokens**: Always use `Bauhaus.*` instead of raw values
3. **Test compliance**: Run contract checks before pushing
4. **Add tests**: Use `assertOperationValid()` for async operations

### For Reviewers

#### PR Checklist
- [ ] All CI gates passing (GitHub Actions)
- [ ] No new contract violations introduced
- [ ] Design tokens used consistently
- [ ] Accessibility labels present
- [ ] Performance budgets respected

## Contract Development

### Creating a New Contract

1. **Define the principle** in `priority_matrix.md`
2. **Create a ticket** in `Tickets/` with:
   - Clear acceptance criteria
   - Measurable metrics
   - Implementation guidance
3. **Add enforcement**:
   - CI script in `Scripts/ci/`
   - Test helpers in `Tests/`
   - Design tokens in `DesignSystem.swift`
4. **Document** in this README

### Contract Anatomy

Every contract must have:
- **Verifiable rules**: Can be checked automatically
- **Clear violations**: Unambiguous pass/fail
- **Enforcement mechanism**: CI gate, test, or linter
- **Remediation path**: How to fix violations
- **Metrics**: Coverage, violation count, etc.

## Success Metrics

### Coverage
- **Design Token Coverage**: 84% → **100%** (target)
- **Button Style Coverage**: 56% → **100%** (target)
- **Accessibility Label Coverage**: TBD → **100%** (target)

### Quality
- **Contract Violations**: 26 → **0** (target)
- **Regression Rate**: TBD → **<5%** (target)
- **Remediation Time**: TBD → **<1 day** (target)

### Performance
- **PDF Import**: TBD → **<200ms/page** (budget)
- **Web Capture**: TBD → **<500ms** (budget)
- **UI Render**: TBD → **<16ms** (60fps budget)

## References

- **Priority Matrix**: [`priority_matrix.md`](../priority_matrix.md)
- **Performance Budgets**: [`PerformanceBudgets.md`](PerformanceBudgets.md)
- **Enforcement Status**: [`ContractEnforcementStatus.md`](ContractEnforcementStatus.md)
- **Design System**: [`Sources/AnigmaAppMac/DesignSystem.swift`](../Sources/AnigmaAppMac/DesignSystem.swift)

## FAQ

### Why are contracts so strict?
**Consistency compounds.** Small deviations accumulate into technical debt. Strict contracts prevent drift.

### What if I need to violate a contract?
Add a `// OK: <reason>` comment. The CI scripts will ignore it. But you'll need to justify it in review.

### How do I know which contract applies?
Check the `priority_matrix.md` or the relevant ticket. When in doubt, ask in PR review.

### Can contracts change?
Yes, but changes require:
1. Update to `priority_matrix.md`
2. Update to enforcement scripts
3. Migration plan for existing violations
4. Team consensus

---

**Last Updated**: 2026-01-07  
**Maintained By**: Anigma Core Team  
**Status**: ⚠️ Active Development (26 violations pending)
