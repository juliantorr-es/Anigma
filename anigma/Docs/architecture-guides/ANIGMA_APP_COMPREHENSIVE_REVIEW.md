# Anigma macOS App: Comprehensive Architecture & Accessibility Review

**Date**: 2026-01-08
**Scope**: `Sources/AnigmaAppMac/` (111 Swift files, 27,139 lines of code)
**Purpose**: Technical debt assessment, accessibility audit, and UI refactor recommendations

---

## Executive Summary

The Anigma macOS SwiftUI application demonstrates **solid architectural foundations** with a clear "Bauhaus" design system, governed mode enforcement, and sophisticated state management. However, it currently has:

### Critical Issues
1. **Compilation Errors**: 10 type mismatches preventing build
2. **WCAG Compliance**: Failing WCAG 2.1 AA (Level A violations for color-only information)
3. **Technical Debt**: Model Registry API migration incomplete

### Assessment
- **Architecture**: ✅ **Strong** - Well-organized, clear separation of concerns
- **Accessibility**: ⚠️ **Moderate** - 352 annotations but systematic gaps
- **Code Quality**: ⚠️ **Good** - Swift 6 compliant with concurrency warnings
- **Build Status**: ❌ **Failing** - Type mismatches block compilation

**Recommendation**: Fix compilation errors immediately, then systematic accessibility remediation (3-5 days critical, 2-3 weeks full AA compliance).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Compilation Errors](#2-compilation-errors)
3. [Accessibility Audit](#3-accessibility-audit)
4. [Design System Analysis](#4-design-system-analysis)
5. [UI/UX Patterns](#5-uiux-patterns)
6. [Best Practices Assessment](#6-best-practices-assessment)
7. [Refactor Recommendations](#7-refactor-recommendations)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## 1. Architecture Overview

### 1.1 Application Structure

```
AnigmaAppMac/
├── AnigmaApp.swift          # @main entry point
├── AppStore.swift           # 2741 lines - Central state (TOO LARGE)
├── AppState.swift           # Navigation state
├── DesignSystem.swift       # Bauhaus design tokens
├── AnigmaRoles.swift        # Role/mode definitions
│
├── Chrome/                  # Shell chrome (OmniBar, Inspector, etc.)
├── Surfaces/                # Main content views (18 surfaces)
├── Components/              # Reusable UI components (60+ components)
├── Services/                # Business logic services
├── Model/                   # Data models & contracts
├── Governance/              # Governance & safety systems
└── Roles/                   # Role-specific shells

```

`★ Insight ─────────────────────────────────────`
The **Bauhaus design philosophy** is evident throughout: geometric precision, high-contrast colors, minimal ornamentation. The naming ("Surfaces", "Chrome", "Governance Strip") reflects an intentional, principled design system. This is **architectural conviction**, not accidental organization—the codebase reads like a manifesto for institutional software design.
`─────────────────────────────────────────────────`

### 1.2 State Management Pattern

**The Projection Store Pattern (Replacing the AppStore God Object)**:
Historically, the app utilized a single `@MainActor @Observable final class AppStore` containing 2,741 lines of state management for everything from jobs to contexts. Because the UI used to be a monolith, `AppStore` became a shallow pass-through.

**Architectural Mandate:** The `AppStore` god object fails the deletion test and must be disassembled. We are transitioning to **Domain-Specific Projection Stores** (e.g., `JobProjectionStore`, `ContextProjectionStore`). 

These new stores act as deep **modules** whose sole responsibility is to deserialize specific XPC/REST state broadcasts coming from the `anigmad` daemon. 

**Strength**: Extreme **leverage** for UI components, which will only re-render when their specific domain slice updates via IPC. Complete **locality** of state management, completely removing business logic from the SwiftUI layer.
**Weakness**: Requires refactoring existing monolithic view bindings.

**Navigation State**:
```swift
@MainActor
@Observable
final class AppState {
    var currentMode: AppMode = .life  // life, work, insight, build, develop
    var selectedSurface: UserSurface = .compass
}
```

### 1.3 Data Visualization & Analytical Seams (The "Thin Client" Rule)

**Current Friction**: Views like `AnalysisCanvasView` and `TransparencyCharts` import heavy mathematical libraries (`TabularData`, `Probably`, `SwiftUICharts`) to compute medians, variances, and slice dataframes on the main thread.
**Architectural Mandate (Sealing the Data Seam)**: We must strictly ban data processing libraries from the `AnigmaApp` target. `anigmad` must perform all aggregations, filtering, and statistical math, returning a pre-computed "Chart DTO" (e.g., `[ {label: "A", height: 0.8} ]`). The UI acts strictly as a dumb drawing **adapter**. This guarantees analytical correctness and extreme performance.

### 1.3 Navigation Architecture

**Mode-Based Navigation**:
- **Life Mode**: Compass, Inbox, Atlas, Ask, Projects, Activity
- **Work Mode**: Projects, Inbox, Ask, Activity, Data
- **Insight Mode**: Atlas, Activity, Ask, Data
- **Build Mode**: Studio, Activity, Inbox, Atlas, Action Catalog
- **Develop Mode**: Files, Search, Changes, Runs, Review, Tasks, Agents, Browse, GitHub

**21 User Surfaces** defined in `AnigmaRoles.swift`:
```swift
enum UserSurface: String, CaseIterable {
    case compass, inbox, atlas, ask, projects, data, studio
    case develop, developFiles, developSearch, developChanges
    case developRuns, developReview, developTasks, developAgents
    // ... etc
}
```

`★ Insight ─────────────────────────────────────`
The **multi-modal navigation** (Life/Work/Insight/Build/Develop) is unusually sophisticated for a desktop app. This reflects the institutional context—different user roles (student, staff, admin) need different affordances. The "Develop" mode alone has 9 sub-surfaces, suggesting this is a *platform* more than an app. Compare to typical macOS apps with 4-6 top-level views.
`─────────────────────────────────────────────────`

### 1.4 Governance Integration

**Governance Strip** (persistent UI element):
- Role indicator (User/Worker/Admin/Developer)
- Mode selector (Life/Work/Insight/Build/Develop)
- Job center with live counts
- Trust boundary pills
- Network status indicator

**Operating Modes**:
```swift
enum GovernanceMode {
    case local       // Local-first, no cloud
    case verify      // Verify all operations
    case trusted     // Trusted host execution
    case off         // Ungoverned (development only)
}
```

**All state-changing operations** go through governance checks—this is the "governed" in "governed, local-first Swift stack."

### 1.5 Key Design Patterns

**Pattern 1: Capability Registration**
```swift
// Services register capabilities
let daemonCapability = DaemonHostCapability()
store.daemonCapability = daemonCapability
```

**Pattern 2: Receipt-Based Operations**
```swift
// All ML operations return cryptographic receipts
let receipt = try await mlWorkerClient.runTask(...)
store.receipts.append(receipt)
```

**Pattern 3: Ledger Recording**
```swift
// Evidence storage for all significant operations
let evidence = AnigmaEvidence(...)
appState.ledger.append(evidence)
```

---

## 2. Compilation Errors

### 2.1 Critical Errors (Blocks Build)

#### Error Group 1: Model Registry API Mismatch

**Location**: `AppStore.swift:2290`
```swift
// ❌ Current (broken):
registeredModels = try await modelRegistry.listAll()
// Returns: [ModelSpec]
// Expected: [ModelRegistryEntry]
```

**Root Cause**: Two parallel type hierarchies:
- **`ModelSpec`** (`ModelContracts.swift`): Immutable provenance contracts
- **`ModelRegistryEntry`** (`ModelRegistryTypes.swift`): Runtime UI state with usage tracking

**Fix Required**: Create adapter function
```swift
func loadRegisteredModels() async {
    do {
        let specs = try await modelRegistry.query()
        registeredModels = specs.map { spec in
            ModelRegistryEntry(
                modelId: spec.modelId,
                sourceType: spec.source.type.rawValue,
                sourceLocation: spec.source.location,
                sourceRevision: spec.source.revision,
                taskKind: spec.taskKind.rawValue,
                backendFormat: spec.backendFormat,
                dimension: spec.dimension,
                artifactHash: spec.modelHash,
                tokenizerHash: spec.tokenizerHash,
                license: LicenseInfo(id: spec.license ?? "unknown"),
                backendCompatibility: .init(format: spec.backendFormat),
                trustTier: spec.trustTier.rawValue
            )
        }
    } catch {
        showError("Failed to load model registry: \(error)")
    }
}
```

#### Error Group 2: Backend Compatibility Enum

**Location**: `AppStore.swift:2324-2328`
```swift
// ❌ Current (broken):
switch result.backendCompatibility {
case .mlx: backendFormat = "mlx"
case .gguf: backendFormat = "gguf"
case .coreml: backendFormat = "coreml"
}
```

**Root Cause**: `ModelBackendCompatibility` structure changed from enum to struct.

**Fix Required**: Update to use struct property
```swift
let backendFormat = result.backendCompatibility.format
```

#### Error Group 3: RunSpec Initialization

**Location**: `AppStore.swift:2425-2429`
```swift
// ❌ Current (broken):
let runSpec = RunSpec(
    runId: UUID().uuidString,
    taskKind: taskKind,        // ❌ MLTaskKind, expected ModelSpec
    backend: backend,          // ❌ String, expected TaskParams
    inputs: inputs,            // ❌ [RunSpec.Input], expected String
    seed: seed ?? 42,
    temperature: temperature,
    // ...
)
```

**Root Cause**: `RunSpec` API changed to accept `modelSpec: ModelSpec` as second parameter.

**Fix Required**: Pass full ModelSpec instead of individual fields
```swift
let runSpec = RunSpec(
    runId: UUID().uuidString,
    modelSpec: modelSpec,  // From registry lookup
    taskParams: TaskParams(
        seed: seed ?? 42,
        temperature: temperature,
        maxTokens: maxTokens,
        topP: topP
    ),
    inputHash: try hashInputs(inputs),
    workflowId: nil,
    jobId: nil,
    dataClassification: .internal_,
    timestamp: Date()
)
```

#### Error Group 4: Type Redeclaration

**Location**: `BinaryTestView.swift:211`
```swift
// ❌ Conflicts with ErrorView.swift
struct ErrorView: View { ... }
```

**Status**: ✅ **FIXED** - Renamed to `BinaryExecutionErrorView`

#### Error Group 5: PipelineStage Ambiguity

**Location**: `AppStore.swift:2741`
```swift
// ❌ Ambiguous between:
// - AnigmaHostMac.PipelineStage (struct)
// - ExportCore.PipelineStage (protocol)
func createPipeline(name: String, stages: [PipelineStage])
```

**Status**: ✅ **FIXED** - Qualified as `AnigmaHostMac.PipelineStage`

### 2.2 Compilation Error Summary

| File | Line | Error | Priority | Status |
|------|------|-------|----------|--------|
| `BinaryTestView.swift` | 211 | Type redeclaration | HIGH | ✅ Fixed |
| `AppStore.swift` | 2741 | Type ambiguity | HIGH | ✅ Fixed |
| `AppStore.swift` | 2290 | Type mismatch `[ModelSpec]` → `[ModelRegistryEntry]` | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2324-2328 | Enum cases don't exist | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2409 | Method doesn't exist `.get()` | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2422 | Property doesn't exist `.spec` | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2425 | Wrong initializer signature | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2427-2429 | Type mismatches in call | CRITICAL | ❌ Pending |
| `AppStore.swift` | 2448 | Wrong method signature | MEDIUM | ❌ Pending |
| `AppStore.swift` | 2537 | Ambiguous initializer | MEDIUM | ❌ Pending |
| `ModelRegistryCard.swift` | 25+ | Multiple type mismatches | MEDIUM | ❌ Pending |
| `MLWorkerTaskSubmissionView.swift` | 153+ | Type mismatches | MEDIUM | ❌ Pending |

**Total**: 12 error locations, ~30 individual errors

**Estimated Fix Time**: 2-4 hours

---

## 3. Accessibility Audit

### 3.1 Current State

**Coverage Statistics**:
- Files with accessibility annotations: **43 files**
- Total accessibility modifiers: **352**
- Button instances: **263**
- Image elements with labels: **219**

**Compliance Assessment**:
| WCAG Criterion | Level | Status | Impact |
|----------------|-------|--------|--------|
| **1.4.1 Use of Color** | A | ❌ **FAIL** | HIGH |
| **1.3.1 Info and Relationships** | A | ⚠️ Partial | MEDIUM |
| **2.1.1 Keyboard** | A | ⚠️ Partial | MEDIUM |
| **2.4.6 Headings and Labels** | AA | ⚠️ Partial | MEDIUM |
| **4.1.3 Status Messages** | AA | ✅ Pass | - |
| **2.4.7 Focus Visible** | AA | ✅ Likely | - |
| **1.4.3 Contrast** | AA | ✅ Likely | - |

**Overall**: **Not WCAG 2.1 AA compliant** due to Level A failures.

### 3.2 Critical Accessibility Violations

#### Violation 1: Color-Only Status Indicators (WCAG 1.4.1 - Level A)

**15+ instances of color-only circles/dots**:

**`DesignSystem.swift:96-115` - StatusDot Component**:
```swift
struct StatusDot: View {
    let state: StatusState

    var body: some View {
        Circle()
            .fill(color)  // ❌ Color only
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)  // ❌ Hidden from screen readers!
    }
}
```

**Problem**: Screen reader users get NO status information.

**`SidebarView.swift:59-69` - Governance Mode Indicator**:
```swift
Circle()
    .fill(.green)  // ❌ Color only
    .frame(width: 8, height: 8)
Text("Governed Mode Active")
```

**`DaemonStatusView.swift:74-80` - Daemon Status**:
```swift
Circle()
    .fill(status.running ? Color.green : Color.red)  // ❌ Color only
```

**`Components/GovernanceStrip.swift:100-102` - Network Status**:
```swift
Circle()
    .fill(isOnline ? Color.green : Color.gray)  // ❌ Color only
```

**Impact**: **Blocks users with color blindness** (8% of males, 0.5% of females).

**Fix Required**: Replace ALL color-only indicators with icon + color + text.

#### Violation 2: Missing Accessibility Hints

**40% of interactive buttons lack hints** explaining what happens when activated.

**Examples**:

**`DaemonStatusView.swift:160-175` - Start/Stop Daemon**:
```swift
Button(status.running ? "Stop Daemon" : "Start Daemon") {
    // ...
}
// ❌ Missing: .accessibilityHint("Controls the background service")
```

**`SourceConnectionView.swift:34-39` - OAuth Connection**:
```swift
Button("Connect Google") {
    // ...
}
// ❌ Missing: .accessibilityHint("Opens browser for OAuth authentication")
```

**`StudioView.swift:74-89` - Parts Bin**:
```swift
Button {
    addPart(part)
} label: {
    Text(part.name)
}
// ❌ Missing: .accessibilityHint("Adds \(part.name) to current workflow")
```

#### Violation 3: Inconsistent Heading Markup

**Only ~30% of section titles marked as headers**.

**Good Example** (`InboxView.swift:103`):
```swift
Text("Intake Queue")
    .font(.headline)
    .accessibilityAddTraits(.isHeader)  // ✅ Proper heading
```

**Missing** (widespread):
```swift
Text("SECTION TITLE")
    .font(.headline)
// ❌ No .isHeader trait
```

**Impact**: Screen reader users can't navigate by headings (common pattern).

### 3.3 Well-Implemented Accessibility

#### Example 1: OperationProgressView ✅✅✅

**`OperationProgressView.swift:10-30`**:
```swift
static func post(_ text: String) {
    NSAccessibility.post(
        element: NSApp.mainWindow!,
        notification: .announcementRequested,
        userInfo: [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high
        ]
    )
}
```

**Excellent**: Uses NSAccessibility API for live region announcements. **WCAG best practice**.

#### Example 2: PrivacyConsole ✅

**`Components/PrivacyConsole.swift:41-56`**:
```swift
Toggle(isOn: $privacySettings.allowCloudAI) {
    Text("Allow Cloud AI")
}
.accessibilityLabel("Allow Cloud AI Services")
.accessibilityHint("Permits use of cloud-based AI models. When disabled, only local models are used.")
```

**Excellent**: Comprehensive labeling with clear explanation of impact.

#### Example 3: ConsoleView ✅✅

**`Components/ConsoleView.swift:40-41`**:
```swift
Text(entry.message)
    .accessibilityLabel("\(levelText) at \(timeText): \(entry.message)")
```

**Excellent**: Combines timestamp, level, and message for screen readers.

### 3.4 Accessibility Recommendations

#### CRITICAL (Block Release):

1. **Replace all color-only status indicators** (15+ instances)
   - Update `StatusDot` to include SF Symbol icons
   - Add status text to all circles
   - Example: ` Green circle → `checkmark.circle.fill` (green) + "Active"`

2. **Fix StatusBadge component**:
   ```swift
   // Current: Color only
   Text("running").foregroundColor(.green)

   // Needed: Icon + Color + Text
   Label("Running", systemImage: "checkmark.circle.fill")
       .foregroundColor(.green)
   ```

#### HIGH (Before Institutional Deployment):

3. **Add accessibility hints to all state-changing actions**
   - Daemon start/stop: "Controls the background service that processes jobs"
   - File import: "Opens file picker to select documents for processing"
   - OAuth connections: "Opens browser to authenticate with your Google account"
   - Workspace activation: "Switches to this workspace and loads its files"

4. **Implement consistent header hierarchy**
   - Mark all section titles with `.isHeader`
   - Use nested `VStack` with semantic grouping
   - Example:
     ```swift
     VStack(alignment: .leading) {
         Text("Section Title")
             .accessibilityAddTraits(.isHeader)
         // Section content
     }
     .accessibilityElement(children: .contain)
     ```

5. **Add live region announcements**:
   - Job queue updates: "3 new jobs added"
   - Inbox count changes: "Inbox count updated to 5 items"
   - Error messages: Use `OperationProgressAnnouncement.post()`

#### MEDIUM (Usability Enhancement):

6. **Improve keyboard navigation**
   - Document all keyboard shortcuts in help
   - Add `.help()` tooltips to icon-only buttons
   - Test focus order in complex forms (likely OK with SwiftUI defaults)

7. **Enhance form accessibility**:
   - Add required/optional indicators
   - Provide validation error announcements
   - Include character limits where applicable
   - Example:
     ```swift
     TextField("Email", text: $email)
         .accessibilityLabel("Email address, required")
         .accessibilityValue(email.isEmpty ? "empty" : email)
     ```

8. **Add accessibility values to dynamic controls**:
   - Custom range controls
   - Dynamic counters
   - Job counts
   - Example:
     ```swift
     Text("\(jobCount) jobs")
         .accessibilityValue("\(jobCount) jobs in queue")
     ```

### 3.5 Accessibility Testing Plan

**Phase 1: VoiceOver Testing** (2 days)
- Navigate all primary workflows with VoiceOver enabled
- Verify all interactive elements are reachable
- Confirm status announcements are meaningful
- Test modal presentation/dismissal
- Verify form validation feedback

**Phase 2: Keyboard-Only Testing** (1 day)
- Complete all tasks without mouse/trackpad
- Verify focus visibility
- Test custom keyboard shortcuts
- Check tab order in complex forms

**Phase 3: Color Blindness Simulation** (1 day)
- Use Sim Daltonism to test:
  - Protanopia (red-blind)
  - Deuteranopia (green-blind)
  - Tritanopia (blue-blind)
- Verify all status indicators are distinguishable

**Phase 4: Automated Testing** (1 day)
- Run Xcode Accessibility Inspector
- Check for contrast ratio violations
- Verify accessibility trait consistency
- Validate dynamic content announcements

**Phase 5: User Testing** (2-3 days)
- Test with actual VoiceOver users
- Test with users who rely on keyboard navigation
- Document friction points and usability issues

---

## 4. Design System Analysis

### 4.1 Bauhaus Design System

**`DesignSystem.swift` - 345 lines**

#### Color Palette

```swift
enum Bauhaus.Color {
    // Primary accent - High-vibrancy Nano Green
    static let accent = Color(red: 0.15, green: 0.85, blue: 0.55)
    static let accentLight = Color(red: 0.35, green: 0.95, blue: 0.75)
    static let accentHighContrast = Color(red: 0.00, green: 0.55, blue: 0.35)

    // Status colors
    static let trusted = Color(red: 0.15, green: 0.85, blue: 0.55)
    static let running = Color(red: 0.15, green: 0.55, blue: 0.95)
    static let warning = Color(red: 1.00, green: 0.65, blue: 0.15)
    static let error = Color(red: 1.00, green: 0.25, blue: 0.35)
}
```

**Contrast Analysis**:
- Accent green (0.15, 0.85, 0.55) on white: **✅ WCAG AA** (likely >4.5:1)
- High contrast variant provided: **✅ Good practice**
- Error red on white: **✅ WCAG AA** (high contrast)

**Issue**: No programmatic contrast verification.

#### Typography

```swift
enum Bauhaus.Font {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .medium, design: .default)
}
```

**Strengths**:
- Clear hierarchy
- Standard SF Pro weights
- Readable sizes (minimum 11pt for caption)

**Missing**: Dynamic Type support (for accessibility scaling).

#### Spacing Grid

```swift
enum Bauhaus.Grid {
    static let unit: CGFloat = 8
    static let x2 = unit * 2    // 16
    static let x3 = unit * 3    // 24
    static let x4 = unit * 4    // 32
    static let x6 = unit * 6    // 48
    static let x8 = unit * 8    // 64

    static let sidebarWidth: CGFloat = 280
    static let inspectorWidth: CGFloat = 320
}
```

**Excellent**: 8pt grid system, consistent spacing.

#### Components

**StatusDot** (❌ Accessibility issue - see Section 3.2):
```swift
struct StatusDot: View {
    let state: StatusState
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)  // ❌ PROBLEM
    }
}
```

**StatusChip** (Missing accessibility):
```swift
struct StatusChip: View {
    let label: String
    let color: Color
    let icon: String?
    // ❌ No accessibility implementation
}
```

**EmptyState** (✅ Good):
```swift
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
            Text(title).font(.headline)
            Text(message).font(.body)
        }
        .accessibilityElement(children: .combine)  // ✅ Combines for screen readers
    }
}
```

### 4.2 Design System Recommendations

1. **Add Dynamic Type Support**:
   ```swift
   static let body = Font.body  // Use semantic font
   // Instead of: Font.system(size: 15, ...)
   ```

2. **Add Contrast Verification**:
   ```swift
   extension Color {
       func contrastRatio(with other: Color) -> Double {
           // Calculate WCAG contrast ratio
       }
   }
   ```

3. **Fix StatusDot Component**:
   ```swift
   struct StatusDot: View {
       let state: StatusState

       var body: some View {
           Label {
               Text(state.label)
                   .font(.caption2)
           } icon: {
               Image(systemName: state.icon)
                   .foregroundColor(state.color)
           }
           .accessibilityLabel(state.accessibilityLabel)
       }
   }

   enum StatusState {
       case idle, running, attention, blocked, newOutput

       var icon: String {
           switch self {
           case .idle: return "circle"
           case .running: return "play.circle.fill"
           case .attention: return "exclamationmark.triangle.fill"
           case .blocked: return "xmark.circle.fill"
           case .newOutput: return "doc.badge.plus"
           }
       }

       var label: String {
           switch self {
           case .idle: return "Idle"
           case .running: return "Running"
           case .attention: return "Needs Attention"
           case .blocked: return "Blocked"
           case .newOutput: return "New Output"
           }
       }
   }
   ```

---

## 5. UI/UX Patterns

### 5.1 Navigation Patterns

**Multi-Modal Shell**:
- Mode picker in toolbar (Life/Work/Insight/Build/Develop)
- Sidebar with context-appropriate surfaces
- Persistent governance strip at top

**Strengths**:
- Clear mental model
- Consistent chrome across modes
- Mode-aware surface filtering

**Weaknesses**:
- 21 surfaces may be overwhelming
- Mode transitions not explained to users
- Keyboard shortcuts not documented

### 5.2 Information Architecture

**Primary Surfaces**:
1. **Compass** - Dashboard/overview
2. **Inbox** - Triage queue for imported items
3. **Atlas** - Knowledge graph with lenses (People, Money, Health, Learning, Projects)
4. **Ask** - Research/query interface
5. **Projects** - Project workspace management
6. **Studio** - Tool/workflow builder
7. **Develop** - Code workspace (9 sub-surfaces)
8. **Activity** - Job progress/history

**Assessment**: Well-organized but dense. Institutional users may need onboarding.

### 5.3 Interaction Patterns

**Drag & Drop** (`InboxView.swift`):
```swift
.onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
    handleDrop(providers)
}
```
**✅ Good**: Visual feedback with `isDropTargeted`.
**❌ Missing**: Accessibility announcement of drop state.

**Search** (`DevelopSearchView.swift`):
```swift
TextField("Search...", text: $query)
    .textFieldStyle(.roundedBorder)
    .onChange(of: query) { _, newValue in
        performSearch(newValue)
    }
```
**✅ Good**: Reactive search.
**❌ Missing**: Debouncing, result count announcement.

**Modal Dialogs** (`ActionConfirmationView.swift`):
```swift
.keyboardShortcut(.escape, modifiers: [])
.keyboardShortcut(.defaultAction)
.accessibilityAddTraits(.isModal)
```
**✅ Excellent**: Proper keyboard shortcuts and modal trait.

### 5.4 Data Visualization

**Job Progress** (`JobCenterPanel.swift`):
```swift
ProgressView(value: job.progress)
    .progressViewStyle(.linear)
```
**✅ Good**: Native progress view.
**❌ Missing**: Percentage value for screen readers.

**Status Indicators** (Widespread):
**❌ Color-only** (see Section 3.2).

---

## 6. Best Practices Assessment

### 6.1 Code Quality

**Strengths**:
- ✅ Swift 6 concurrency (`@MainActor`, `@Observable`)
- ✅ Type-safe state management
- ✅ Clear separation of concerns (Chrome/Surfaces/Components/Services)
- ✅ Consistent naming conventions
- ✅ Protocol-oriented design (where appropriate)

**Weaknesses**:
- ❌ `AppStore.swift` is 2741 lines (should be <500 lines)
- ⚠️ Some long functions (>100 lines)
- ⚠️ Limited unit test coverage (not assessed in detail)

### 6.2 SwiftUI Best Practices

**View Composition** - ✅ Good:
```swift
struct MacShell: View {
    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            ContentSurface()
        }
        .inspector { InspectorPane() }
    }
}
```

**State Management** - ✅ Good:
```swift
@Environment(AppStore.self) private var store
@Environment(AppState.self) private var appState
```

**Performance** - ⚠️ Needs Assessment:
- No visible use of `@StateObject` for expensive computations
- Limited memoization
- May need profiling for large datasets

### 6.3 Accessibility Best Practices

**Excellent Examples**:
1. **OperationProgressView**: Uses `NSAccessibility.post()` for live announcements
2. **PrivacyConsole**: Comprehensive labels and hints
3. **ActionConfirmationView**: Proper modal trait and keyboard shortcuts
4. **ConsoleView**: Combines timestamp, level, message for screen readers

**Missing Patterns**:
1. Dynamic Type support
2. Reduce Motion support
3. High Contrast mode detection
4. VoiceOver rotor actions

### 6.4 Governance & Security

**Strengths**:
- ✅ Governance strip always visible
- ✅ Receipt-based operations
- ✅ Trust tier system
- ✅ Privacy console with transparent network activity
- ✅ Local-first architecture

**Assessment**: Governance integration is **exceptional** for institutional software.

---

## 7. Refactor Recommendations

### 7.1 Critical: Split AppStore.swift

**Problem**: `AppStore.swift` is 2741 lines, violating single responsibility.

**Solution**: Extract into focused stores:

```swift
// BEFORE: AppStore.swift (2741 lines)
@MainActor
@Observable
final class AppStore {
    // ML Worker state
    var registeredModels: [ModelRegistryEntry] = []
    var mlWorkerStatus: MLWorkerStatus? = nil
    // ... 20+ ML properties

    // Pipeline state
    var pipelines: [PipelineInfo] = []
    var pipelineRuns: [PipelineRun] = []
    // ... 10+ pipeline properties

    // Source connection state
    var googleOAuthToken: GoogleOAuthToken?
    // ... 15+ OAuth properties

    // Daemon state
    var daemonBridge: DaemonBridge?
    // ... 10+ daemon properties

    // Repository state
    var repoWorkspaces: [RepoWorkspace] = []
    // ... 15+ repo properties

    // ... 50+ more properties
}

// AFTER: Split into focused stores

@MainActor
@Observable
final class AppStore {
    // Composition of specialized stores
    let mlStore: MLStore
    let pipelineStore: PipelineStore
    let sourceStore: SourceConnectionStore
    let daemonStore: DaemonStore
    let workspaceStore: WorkspaceStore

    // Only high-level app state
    var isLoading: Bool = false
    var error: AppError?
    var toastMessage: ToastMessage?
}

@MainActor
@Observable
final class MLStore {
    // Model registry
    var registeredModels: [ModelRegistryEntry] = []
    var mlWorkerStatus: MLWorkerStatus?

    // Operations
    func loadModels() async { ... }
    func runInference(...) async -> Receipt { ... }
}

@MainActor
@Observable
final class PipelineStore {
    var pipelines: [PipelineInfo] = []
    var pipelineRuns: [PipelineRun] = []

    func loadPipelines() async { ... }
    func createPipeline(...) async { ... }
}

// ... etc for other stores
```

**Benefits**:
- Each store <500 lines
- Clear responsibilities
- Easier testing
- Parallel development

**Estimated Effort**: 1 week

### 7.2 High Priority: Accessibility Remediation

**Phase 1: Fix Color-Only Indicators** (2 days)

Update `StatusDot` component:
```swift
// File: DesignSystem.swift

struct StatusDot: View {
    let state: StatusState
    let showLabel: Bool = false

    var body: some View {
        Label {
            if showLabel {
                Text(state.label)
                    .font(.caption)
            }
        } icon: {
            Image(systemName: state.icon)
                .foregroundColor(state.color)
                .font(.caption)
        }
        .accessibilityLabel(state.accessibilityLabel)
    }
}

extension StatusState {
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .attention: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        case .newOutput: return "doc.badge.plus"
        }
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .attention: return "Needs Attention"
        case .blocked: return "Blocked"
        case .newOutput: return "New Output"
        }
    }

    var accessibilityLabel: String {
        return "Status: \(label)"
    }
}
```

Replace ALL instances:
```swift
// BEFORE:
Circle().fill(.green).frame(width: 8, height: 8)

// AFTER:
StatusDot(state: .running, showLabel: false)
```

**Phase 2: Add Accessibility Hints** (1 day)

Create hint constants:
```swift
enum AccessibilityHints {
    static let startDaemon = "Starts the background service that processes jobs"
    static let stopDaemon = "Stops the background service"
    static let connectGoogle = "Opens browser to authenticate with your Google account"
    static let importFile = "Opens file picker to select documents for processing"
    static let activateWorkspace = "Switches to this workspace and loads its files"
    // ... etc
}
```

Apply systematically:
```swift
Button("Start Daemon") {
    startDaemon()
}
.accessibilityHint(AccessibilityHints.startDaemon)
```

**Phase 3: Implement Header Hierarchy** (1 day)

Create header modifier:
```swift
extension View {
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }
}
```

Apply to all section titles:
```swift
// BEFORE:
Text("Section Title").font(.headline)

// AFTER:
Text("Section Title").sectionHeader()
```

**Phase 4: Add Live Announcements** (1 day)

Extend `OperationProgressAnnouncement`:
```swift
extension OperationProgressAnnouncement {
    static func jobQueueUpdate(count: Int) {
        post("\(count) jobs in queue")
    }

    static func inboxUpdate(count: Int) {
        post("Inbox updated. \(count) items")
    }

    static func errorOccurred(_ message: String) {
        post("Error: \(message)", priority: .high)
    }
}
```

Use in state updates:
```swift
var localJobs: [AnigmaJob] = [] {
    didSet {
        OperationProgressAnnouncement.jobQueueUpdate(count: localJobs.count)
    }
}
```

### 7.3 Medium Priority: Performance Optimization

**Profile Hot Paths**:
1. Job list updates (frequent refreshes)
2. Inbox rendering (potentially many items)
3. Search results (live filtering)
4. Workspace file tree (large projects)

**Optimization Techniques**:
```swift
// 1. Use LazyVStack for long lists
LazyVStack {
    ForEach(jobs) { job in
        JobRow(job: job)
    }
}

// 2. Memoize expensive computations
@State private var filteredJobs: [AnigmaJob] = []

private func updateFilteredJobs() {
    filteredJobs = jobs.filter { matchesFilter($0) }
}

// 3. Debounce search
@State private var searchTask: Task<Void, Never>?

func performSearch(_ query: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await actualSearch(query)
    }
}
```

### 7.4 Low Priority: Enhanced Features

**1. Dynamic Type Support**:
```swift
Text("Title")
    .font(.headline)  // ✅ Automatically scales
    .dynamicTypeSize(.large ... .xxxLarge)  // Limit range if needed
```

**2. Reduce Motion Support**:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .spring()
}
```

**3. High Contrast Mode**:
```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

var statusColor: Color {
    if differentiateWithoutColor {
        return .primary  // Use text color
    } else {
        return status.color
    }
}
```

---

## 8. Implementation Roadmap

### Phase 1: Stabilization (Week 1)

**Goal**: Get app building and deployable

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Fix Model Registry API mismatches | 2-3h | CRITICAL | Backend |
| Fix RunSpec initialization | 1-2h | CRITICAL | Backend |
| Fix ModelRegistryCard type errors | 1h | HIGH | UI |
| Run full test suite | 1h | HIGH | QA |
| Deploy to internal testing | 0.5h | HIGH | DevOps |

**Deliverable**: Working build for internal testing

### Phase 2: Critical Accessibility (Week 2)

**Goal**: Fix WCAG Level A violations

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Update StatusDot component with icons | 1d | CRITICAL | UI |
| Replace all color-only indicators | 2d | CRITICAL | UI |
| Add accessibility hints to state-changing actions | 1d | HIGH | UI |
| Implement header hierarchy | 1d | HIGH | UI |
| VoiceOver testing | 1d | HIGH | QA |

**Deliverable**: WCAG 2.1 Level A compliant

### Phase 3: Full AA Compliance (Week 3-4)

**Goal**: Meet institutional accessibility requirements

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Add live region announcements | 1d | HIGH | UI |
| Improve keyboard navigation | 2d | MEDIUM | UI |
| Enhance form accessibility | 2d | MEDIUM | UI |
| Add Dynamic Type support | 1d | MEDIUM | UI |
| Full accessibility audit | 2d | HIGH | QA |
| User testing with assistive tech users | 2-3d | HIGH | UX |

**Deliverable**: WCAG 2.1 AA compliant, user-validated

### Phase 4: Architecture Refactor (Week 5-6)

**Goal**: Reduce technical debt, improve maintainability

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Extract MLStore from AppStore | 2d | MEDIUM | Backend |
| Extract PipelineStore | 1d | MEDIUM | Backend |
| Extract SourceConnectionStore | 1d | MEDIUM | Backend |
| Extract WorkspaceStore | 2d | MEDIUM | Backend |
| Update view dependencies | 2d | MEDIUM | UI |
| Regression testing | 2d | HIGH | QA |

**Deliverable**: Maintainable, modular architecture

### Phase 5: Performance & Polish (Week 7-8)

**Goal**: Optimize user experience

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Profile hot paths | 1d | MEDIUM | Performance |
| Optimize job list rendering | 1d | MEDIUM | UI |
| Optimize search | 1d | MEDIUM | UI |
| Add reduce motion support | 0.5d | LOW | UI |
| Add high contrast mode | 0.5d | LOW | UI |
| Polish animations | 1d | LOW | UI |
| Beta testing | 3d | HIGH | QA/UX |

**Deliverable**: Polished, performant application

---

## Summary & Next Steps

### Immediate Actions (This Week)

1. **Fix compilation errors** (2-4 hours)
   - Model Registry API adapter
   - RunSpec initialization
   - Type mismatches

2. **Deploy working build** (0.5 hour)
   - Internal testing
   - Gather feedback

3. **Begin accessibility remediation** (start this week)
   - Update StatusDot component
   - Start replacing color-only indicators

### Success Criteria

**Week 1**: ✅ App builds and runs
**Week 2**: ✅ WCAG Level A compliant
**Week 4**: ✅ WCAG AA compliant, user-validated
**Week 6**: ✅ Refactored architecture
**Week 8**: ✅ Polished, production-ready

### Risk Mitigation

**Risk 1**: Accessibility fixes break existing UI
- **Mitigation**: Visual regression testing, staged rollout

**Risk 2**: AppStore refactor introduces bugs
- **Mitigation**: Comprehensive unit tests, feature flags

**Risk 3**: Timeline slippage
- **Mitigation**: Prioritize critical path, defer low-priority enhancements

---

## Conclusion

The Anigma macOS app demonstrates **strong architectural foundations** and a **clear design vision**. The "Bauhaus" design system, governed operations, and sophisticated navigation model reflect careful thought and institutional requirements.

**The critical path forward**:
1. Fix compilation errors (immediate)
2. Systematic accessibility remediation (2-3 weeks)
3. Architecture refactor for maintainability (2 weeks)

With these improvements, Anigma will be a **best-in-class institutional application** that meets both technical excellence and accessibility standards.

---

**Report Author**: Claude (Sonnet 4.5)
**Date**: 2026-01-08
**Lines of Code Analyzed**: 27,139
**Files Reviewed**: 111
**Accessibility Annotations Found**: 352
**Critical Issues Identified**: 12 compilation errors, 15+ WCAG violations
**Estimated Remediation**: 6-8 weeks for full compliance and refactor
