# Manual Review Guide: Remaining Contract Violations

**Status**: 🟡 **15 VIOLATIONS REQUIRE MANUAL REVIEW**  
**Date**: 2026-01-07T06:58:00Z  
**Campaign**: ANIGMA-RC-001 Phase 3

---

## Overview

The automated remediation campaign successfully fixed **42% of violations** (26 → 15). The remaining **15 critical violations** require manual review because they involve context-specific semantic decisions that cannot be safely automated.

---

## Remaining Violations Breakdown

### 🎨 Color Violations (9 remaining)

**Location**: Find them with:
```bash
grep -rn "Color\.\(red\|blue\|green\|orange\|purple\|yellow\|gray\)" \
  Sources/AnigmaAppMac/Surfaces \
  Sources/AnigmaAppMac/Components \
  | grep -v "Bauhaus.Color"
```

**Why Manual Review?**
- Context-specific semantic meaning (e.g., status indicators)
- Dynamic color computation
- Third-party component integration
- Special visual effects

**Review Checklist**:
- [ ] Is this a semantic color (error, warning, success)?
- [ ] Is this a UI element color (accent, surface, text)?
- [ ] Is this a status indicator?
- [ ] Is this computed or dynamic?

**Semantic Mapping Guide**:
```swift
// Status & Feedback
Color.red    → Bauhaus.Color.error      // Errors, failures, danger
Color.green  → Bauhaus.Color.trusted    // Success, verified, safe
Color.orange → Bauhaus.Color.warning    // Warnings, caution
Color.yellow → Bauhaus.Color.warning    // Alerts, attention needed

// UI Elements
Color.blue   → Bauhaus.Color.accent     // Primary actions, links
Color.purple → Bauhaus.Color.accent     // Secondary accent
Color.gray   → Bauhaus.Color.textSecondary  // Disabled, secondary text

// Special Cases
Color.black  → Bauhaus.Color.textPrimary
Color.white  → Bauhaus.Color.surface
```

---

### 🔤 Font Violations (6 remaining)

**Location**: Find them with:
```bash
grep -rn "\.font(\.system\|Font\.system" \
  Sources/AnigmaAppMac/Surfaces \
  Sources/AnigmaAppMac/Components \
  | grep -v "Bauhaus.Font"
```

**Why Manual Review?**
- Custom font weights (thin, ultralight, heavy)
- Monospace fonts for code display
- Dynamic font sizing
- Accessibility font scaling

**Review Checklist**:
- [ ] Is this a standard size (12, 14, 18, 20)?
- [ ] Does it have a custom weight?
- [ ] Is it monospace/code font?
- [ ] Is the size dynamic/computed?

**Semantic Mapping Guide**:
```swift
// Standard Sizes
.font(.system(size: 20, ...)) → .font(Bauhaus.Font.header)
.font(.system(size: 18, ...)) → .font(Bauhaus.Font.subHeader)
.font(.system(size: 14, ...)) → .font(Bauhaus.Font.body)
.font(.system(size: 12, ...)) → .font(Bauhaus.Font.caption)

// Special Cases
.font(.system(size: X, design: .monospaced)) → .font(Bauhaus.Font.mono)
.font(.system(size: X, weight: .bold))       → Review context
.font(.system(size: X, design: .rounded))    → May need custom token
```

---

## Step-by-Step Review Process

### Step 1: Identify Violation
```bash
# Run the search
grep -rn "Color\.red" Sources/AnigmaAppMac/Surfaces
```

**Example Output**:
```
Sources/AnigmaAppMac/Surfaces/JobCenterView.swift:142:  .foregroundColor(Color.red)
```

### Step 2: Understand Context
Open the file and review the surrounding code:
```swift
// Line 140-145
if job.status == .failed {
    Image(systemName: "xmark.circle.fill")
        .foregroundColor(Color.red)  // ← Violation
}
```

**Context**: This is a failure indicator.

### Step 3: Apply Semantic Mapping
```swift
// Before
.foregroundColor(Color.red)

// After
.foregroundColor(Bauhaus.Color.error)
```

**Rationale**: Red is used to indicate an error state, so `Bauhaus.Color.error` is semantically correct.

### Step 4: Verify
```bash
# Run contract check
./Scripts/ci/check-design-tokens.sh

# Run tests
swift test
```

### Step 5: Document
Add a comment if the mapping is non-obvious:
```swift
// Contract: Using semantic error color for failed job status
.foregroundColor(Bauhaus.Color.error)
```

---

## Common Patterns & Solutions

### Pattern 1: Status Indicators
**Before**:
```swift
switch status {
case .success: Color.green
case .warning: Color.yellow
case .error: Color.red
}
```

**After**:
```swift
switch status {
case .success: Bauhaus.Color.trusted
case .warning: Bauhaus.Color.warning
case .error: Bauhaus.Color.error
}
```

### Pattern 2: Interactive Elements
**Before**:
```swift
Button("Action") { ... }
    .foregroundColor(Color.blue)
```

**After**:
```swift
Button("Action") { ... }
    .foregroundColor(Bauhaus.Color.accent)
```

### Pattern 3: Code Display
**Before**:
```swift
Text(codeSnippet)
    .font(.system(size: 12, design: .monospaced))
```

**After**:
```swift
Text(codeSnippet)
    .font(Bauhaus.Font.mono)
```

### Pattern 4: Dynamic Sizing
**Before**:
```swift
.font(.system(size: dynamicSize))
```

**After** (if size is predictable):
```swift
// Add to DesignSystem.swift if needed
.font(Bauhaus.Font.dynamicBody(size: dynamicSize))
```

**After** (if truly dynamic):
```swift
// OK: Dynamic sizing based on runtime state
.font(.system(size: dynamicSize))  // OK: runtime-computed
```

---

## Edge Cases

### Case 1: Third-Party Components
If a color/font is required by a third-party library:
```swift
// OK: Required by ThirdPartyView API
ThirdPartyView(color: Color.blue)
```

Add a comment:
```swift
// OK: ThirdPartyView requires Color, not semantic token
ThirdPartyView(color: Color.blue)
```

### Case 2: Gradients & Effects
For gradients or special effects:
```swift
// Before
LinearGradient(colors: [Color.blue, Color.purple], ...)

// After
LinearGradient(colors: [Bauhaus.Color.accent, Bauhaus.Color.accent.opacity(0.7)], ...)
```

### Case 3: Computed Colors
For algorithmically computed colors:
```swift
// OK: Computed from user input or algorithm
let computedColor = Color(hue: userHue, saturation: 0.8, brightness: 0.9)
```

---

## Verification Checklist

After each fix:
- [ ] Code compiles without errors
- [ ] Visual appearance is correct (run app)
- [ ] Semantic meaning is preserved
- [ ] Contract check passes
- [ ] Tests pass
- [ ] Commit with descriptive message

---

## Commit Template

```bash
git commit -m "fix: migrate [file] to design tokens (manual review)

- Replaced Color.red with Bauhaus.Color.error (failure indicator)
- Replaced .font(.system(size: 14)) with Bauhaus.Font.body
- Context: [brief explanation of semantic choice]

Contract: [contract-001 | contract-002]
Manual review: [reason for manual review]"
```

---

## Progress Tracking

### Color Violations (9 remaining)
- [ ] Violation 1: `[file]:[line]` - `[context]`
- [ ] Violation 2: `[file]:[line]` - `[context]`
- [ ] Violation 3: `[file]:[line]` - `[context]`
- [ ] Violation 4: `[file]:[line]` - `[context]`
- [ ] Violation 5: `[file]:[line]` - `[context]`
- [ ] Violation 6: `[file]:[line]` - `[context]`
- [ ] Violation 7: `[file]:[line]` - `[context]`
- [ ] Violation 8: `[file]:[line]` - `[context]`
- [ ] Violation 9: `[file]:[line]` - `[context]`

### Font Violations (6 remaining)
- [ ] Violation 1: `[file]:[line]` - `[context]`
- [ ] Violation 2: `[file]:[line]` - `[context]`
- [ ] Violation 3: `[file]:[line]` - `[context]`
- [ ] Violation 4: `[file]:[line]` - `[context]`
- [ ] Violation 5: `[file]:[line]` - `[context]`
- [ ] Violation 6: `[file]:[line]` - `[context]`

---

## Success Criteria

**Manual review is complete when**:
- ✅ All 15 violations identified and fixed
- ✅ Contract check passes: `./Scripts/ci/check-design-tokens.sh`
- ✅ All tests pass: `swift test`
- ✅ Visual regression check complete
- ✅ Changes committed with clear rationale

**Target**: 100% design token compliance (0 critical violations)

---

## Need Help?

### Resources
- **Design System**: `Sources/AnigmaAppMac/DesignSystem.swift`
- **Contract Tickets**: `Tickets/009_color_contract.md`, `Tickets/007_legibility_hierarchy_contract.md`
- **Priority Matrix**: `priority_matrix.md`

### Questions to Ask
1. What is the semantic meaning of this color/font?
2. Is this a UI element or content?
3. Is this interactive or static?
4. Does this need to be dynamic?

---

*Last Updated: 2026-01-07T06:58:00Z*  
*Campaign: ANIGMA-RC-001 Phase 3*  
*Status: Ready for Manual Review*
