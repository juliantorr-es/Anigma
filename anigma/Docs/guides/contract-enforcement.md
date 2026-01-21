# Contract Enforcement System

> **Contracts are not documentation—they are executable law.**

---

## Overview

The Anigma Contract System transforms abstract design principles into **mechanically enforceable rules** that govern every aspect of the application. Unlike traditional style guides, these contracts are **verified automatically** on every commit and **block merges** when violated.

### Philosophy

| Traditional Approach (Broken) | Contract Approach (Working) |
|-------------------------------|----------------------------|
| Design Principles → Documentation → Hope developers read it → Drift | Design Principles → Executable Contracts → CI Enforcement → Guaranteed Compliance |

---

## Contract Categories

### System Contracts

| Contract | Ticket | Purpose |
|----------|--------|---------|
| **OperationResult** | 001 | All async ops use OperationResult<T> envelope |
| **Performance** | 006 | Hard latency budgets (e.g., PDF: 200ms/page) |
| **Accessibility** | 002 | WCAG 2.1 AA compliance |

### UI/UX Contracts

| Contract | Ticket | Purpose |
|----------|--------|---------|
| **Legibility & Hierarchy** | 007 | Semantic typography (Inter/Roboto) |
| **Color** | 009 | Semantic palette only, no hardcoded colors |
| **Alignment** | 010 | 12-column grid, Bauhaus.Grid spacing |
| **Affordance** | 011 | Clear visual states, <100ms feedback |
| **Aesthetic-Usability** | 008 | Premium polish, 60fps transitions |

---

## Enforcement Layers

### 1. CI Gates (Automated)

```bash
# Run on every PR
./Scripts/ci/check-accessibility.sh
./Scripts/ci/check-design-tokens.sh
./Scripts/ci/check-performance-budgets.sh
./Scripts/ci/check-type-authority.sh
```

**GitHub Actions**: `.github/workflows/contract-enforcement.yml`

### 2. SwiftLint Rules (Real-time)

| Rule | Severity | Description |
|------|----------|-------------|
| `bauhaus_color_tokens` | **error** | Enforce Bauhaus.Color usage |
| `bauhaus_font_tokens` | **error** | Enforce Bauhaus.Font usage |
| `bauhaus_spacing_tokens` | warning | Enforce Bauhaus.Grid usage |
| `operation_result_async` | warning | Async ops return OperationResult |
| `anigma_error_schema` | warning | Use AnigmaError with stable codes |
| `accessibility_label_required` | warning | Interactive elements need labels |
| `standardized_button_styles` | warning | Use .primaryButtonStyle() etc. |

### 3. Analytics Pipeline (Historical)

```swift
// Initialize analytics
let analytics = ContractAnalytics(storageURL: storageURL)

// Record violation
await analytics.recordViolation(ContractViolation(
    contractName: "design-tokens",
    severity: .critical,
    filePath: "Sources/AnigmaAppMac/Surfaces/CompassView.swift",
    lineNumber: 42,
    violationType: "hardcoded-color",
    message: "Use Bauhaus.Color.error instead",
    suggestedFix: ".foregroundColor(Bauhaus.Color.error)"
))

// Generate report
let report = await analytics.generateReport()
```

### 4. Harmonia Integration (Governed Remediation)

```bash
# Validate contracts
./Scripts/harmonia-contract-bridge.sh validate all

# Generate report
./Scripts/harmonia-contract-bridge.sh report

# Generate remediation proposals
./Scripts/harmonia-contract-bridge.sh remediate
```

---

## Current Status

### Contract Gates

| Contract | Status | Coverage | Violations |
|----------|--------|----------|------------|
| Type Authority | ✅ PASSING | 100% | 0 |
| Design Tokens | ❌ FAILING | 84% | 26 |
| Accessibility | ⏳ READY | TBD | TBD |
| Performance | ⏳ READY | TBD | TBD |

### Known Violations

- **16** hardcoded colors → use `Bauhaus.Color`
- **10** hardcoded fonts → use `Bauhaus.Font`
- **54** hardcoded spacing → use `Bauhaus.Grid`
- **44** unstyled buttons → use `.primaryButtonStyle()`

### Success Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Color Token Coverage | 84% | 100% | 🔴 |
| Font Token Coverage | 90% | 100% | 🔴 |
| Button Style Coverage | 56% | 100% | 🟡 |
| Spacing Token Coverage | 46% | 80% | 🟡 |
| Accessibility Labels | TBD | 100% | ⚪ |

---

## Developer Guide

### Before Committing

```bash
# Run contract checks locally
./Scripts/ci/check-design-tokens.sh
./Scripts/ci/check-accessibility.sh
```

### Fixing Violations

```swift
// ❌ Violates Color Contract
Text("Error").foregroundColor(.red)

// ✅ Compliant
Text("Error").foregroundColor(Bauhaus.Color.error)
```

```swift
// ❌ Violates Font Contract
Text("Title").font(.system(size: 20, weight: .bold))

// ✅ Compliant
Text("Title").font(Bauhaus.Font.header)
```

```swift
// ❌ Violates Affordance Contract
Button("Submit") { /* action */ }

// ✅ Compliant
Button("Submit") { /* action */ }
    .primaryButtonStyle()
```

### Design Tokens Reference

```swift
// ✅ Semantic tokens (ALWAYS use these)
Bauhaus.Color.accent
Bauhaus.Color.error
Bauhaus.Color.success
Bauhaus.Font.header
Bauhaus.Font.body
Bauhaus.Grid.unit      // 8pt
Bauhaus.Grid.x2        // 16pt

// ❌ Hardcoded values (NEVER use)
Color.red
.font(.system(size: 14))
.padding(16)
```

---

## Enforcement Flow

```
Developer writes code
    ↓
SwiftLint validates (real-time in Xcode)
    ↓
Commit to branch
    ↓
CI gates run (automated)
    ↓
Analytics records violations
    ↓
Dashboard updates
    ↓
Harmonia generates remediation proposals
    ↓
Governed patch application
    ↓
Contract compliance verified
```

---

## Remediation Campaigns

### Automated Fix Scripts

```bash
# Color token migration
./Scripts/remediation/fix-color-tokens.sh

# Font token migration
./Scripts/remediation/fix-font-tokens.sh

# Button style migration
./Scripts/remediation/fix-button-styles.sh
```

### Remediation Queue

| Proposal | Type | Files | Severity | Automated |
|----------|------|-------|----------|-----------|
| contract-001 | Color tokens | 16 | Critical | ✅ |
| contract-002 | Font tokens | 10 | Critical | ✅ |
| contract-003 | Button styles | 44 | Warning | ✅ |

---

## PR Review Checklist

- [ ] All CI gates passing (GitHub Actions)
- [ ] No new contract violations introduced
- [ ] Design tokens used consistently
- [ ] Accessibility labels present
- [ ] Performance budgets respected

---

## FAQ

**Why are contracts so strict?**
Consistency compounds. Small deviations accumulate into technical debt. Strict contracts prevent drift.

**What if I need to violate a contract?**
Add a `// OK: <reason>` comment. CI scripts will ignore it, but you'll need to justify it in review.

**How do I know which contract applies?**
Check the contract tickets in `Tickets/` or the priority matrix. When in doubt, ask in PR review.

**Can contracts change?**
Yes, but changes require: update to priority_matrix.md, update to enforcement scripts, migration plan for existing violations, and team consensus.

---

## References

- **Tickets**: `Tickets/001_*.md` through `Tickets/011_*.md`
- **Priority Matrix**: `priority_matrix.md`
- **Performance Budgets**: `PerformanceBudgets.md`
- **Design System**: `Sources/AnigmaAppMac/DesignSystem.swift`
- **SwiftLint Config**: `.swiftlint.yml`
- **CI Scripts**: `Scripts/ci/`
- **Analytics**: `Sources/AnigmaAppMac/Services/ContractAnalytics.swift`
- **Dashboard**: `Sources/AnigmaAppMac/Surfaces/ContractDashboardView.swift`

---

*Consolidated from: ContractSystem.md, ContractEnforcement.md, ContractEnforcementStatus.md, ContractAnalyticsIntegration.md*

*Last Updated: January 10, 2026*
