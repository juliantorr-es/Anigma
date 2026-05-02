# Calm Surface Defaults Audit

## Executive Summary

This document audits the "calm by default" surface defaults for Anigma's assistant UI, ensuring proper progressive disclosure, minimal initial cognitive load, and local-first data presentation.

## Calm Surface Philosophy

**Core Principles:**
- **Calm by Default:** Minimal UI surface area on initial load
- **Progressive Disclosure:** Expand functionality as user engages
- **Local-First:** Prioritize local data and privacy
- **Provenance Tracking:** Always show data source and confidence

## Current Implementation Analysis

### 1. AssistantView (Primary Calm Surface)

**Location:** `anigma/Sources/AnigmaAppMac/Surfaces/AssistantView.swift`

**Current Defaults:**
- ✅ **Initial State:** Shows minimal `assistantHome` view
- ✅ **Progressive Expansion:** `showAnalysisCanvas` flag controls expansion
- ✅ **Animation:** Smooth transitions between states (0.3s easeInOut)
- ✅ **Navigation:** Clear return path from expanded to calm state
- ✅ **Accessibility:** Proper keyboard shortcuts and labels

**Default State Components:**
```swift
// Calm Home Mode (default)
assistantHome
    .transition(.opacity)

// Expanded Analysis Mode (opt-in)
if showAnalysisCanvas {
    AnalysisCanvasView(state: state, isPresented: $showAnalysisCanvas)
}
```

### 2. AnalysisCanvasView (Expanded Surface)

**Location:** `anigma/Sources/AnigmaAppMac/Surfaces/AnalysisCanvasView.swift`

**Current Defaults:**
- ✅ **Entry Point:** Only shown when `showAnalysisCanvas = true`
- ✅ **Provenance:** Shows "calm summary of result confidence"
- ✅ **Structured Data:** Table layer ready for expansion
- ✅ **Visual Design:** Lightweight confidence chart

**Default State Description:**
> "The analysis canvas now keeps the calm summary view, adds a lightweight confidence chart, and leaves the structured table layer ready for TabularData-backed slicing."

### 3. Conversation Message Defaults

**Location:** `anigma/Sources/AnigmaAppMac/AssistantView.swift` (line 209)

**Current Defaults:**
- ✅ **Minimal Structure:** `id`, `role`, `content`, `timestamp`
- ✅ **Sendable:** Thread-safe by default
- ✅ **Codable:** Serialization-ready

### 4. Disclosure Capacity Rules

**Location:** `anigma/Sources/AnigmaAppMac/AssistantView.swift` (line 252)

**Current Defaults:**
- ✅ **Window-Based:** `AssistantDisclosureCapacityWindow`
- ✅ **Rule-Based:** `AssistantDisclosureCapacityRules`
- ✅ **Configurable:** Supports different capacity strategies

## Audit Findings

### ✅ Strengths

1. **Clear State Management:**
   - `showAnalysisCanvas` boolean clearly separates calm vs. expanded states
   - `@State` property wrappers ensure proper SwiftUI lifecycle management

2. **Progressive Disclosure Pattern:**
   - Default view shows minimal UI surface
   - Expansion is user-initiated and reversible
   - Smooth animations prevent jarring transitions

3. **Proper Accessibility:**
   - Keyboard shortcuts for navigation (.escape to return home)
   - Accessibility labels on interactive elements
   - Semantic SwiftUI components

4. **Documentation:**
   - Code comments explain calm-by-default philosophy
   - Example files show intended usage patterns

### ⚠️ Areas for Improvement

1. **Configuration Centralization:**
   - **Issue:** Calm surface defaults are scattered across multiple files
   - **Impact:** Harder to maintain consistent behavior
   - **Recommendation:** Create `CalmSurfaceConfiguration` struct

2. **Default State Testing:**
   - **Issue:** No explicit tests for calm surface defaults
   - **Impact:** Regression risk for default behaviors
   - **Recommendation:** Add snapshot tests for default UI states

3. **Animation Configuration:**
   - **Issue:** Magic numbers for animation durations (0.3s)
   - **Impact:** Inconsistent animation timing
   - **Recommendation:** Define in `CalmSurfaceAnimation` constants

4. **State Persistence:**
   - **Issue:** Calm/expanded state not persisted across sessions
   - **Impact:** Users lose their preferred view mode
   - **Recommendation:** Add user preference for default view mode

## Specific Defaults Audit

### UI Component Defaults

| Component | Current Default | Audit Status | Recommendation |
|-----------|----------------|--------------|----------------|
| Initial View | `assistantHome` | ✅ Good | Keep as default |
| Expansion Trigger | User action | ✅ Good | Keep user-initiated |
| Animation Duration | 0.3s | ⚠️ Magic Number | Move to constants |
| Provenance Visibility | Always shown | ✅ Good | Maintain transparency |
| Confidence Chart | Lightweight | ✅ Good | Keep minimal design |

### Data Presentation Defaults

| Aspect | Current Default | Audit Status | Recommendation |
|--------|----------------|--------------|----------------|
| Message Order | Chronological | ✅ Good | Maintain expected order |
| Provenance Format | Summary + details | ✅ Good | Keep progressive detail |
| Error Handling | Not shown by default | ⚠️ Needs Review | Consider calm error states |
| Loading States | Not implemented | ⚠️ Missing | Add calm loading indicators |

### Behavior Defaults

| Behavior | Current Default | Audit Status | Recommendation |
|----------|----------------|--------------|----------------|
| Session Persistence | Not persisted | ⚠️ Missing | Add user preference |
| Keyboard Navigation | Escape to return | ✅ Good | Maintain and document |
| Focus Management | Auto-focus on expansion | ❓ Unknown | Verify and test |
| Accessibility | Standard labels | ✅ Good | Expand coverage |

## Recommendations

### Immediate Actions (P0)

1. **Create CalmSurfaceConfiguration:**
   ```swift
   struct CalmSurfaceConfiguration {
       static let defaultAnimationDuration: Double = 0.3
       static let defaultViewMode: AssistantViewMode = .calm
       static let showProvenanceByDefault: Bool = true
       static let confidenceChartStyle: ConfidenceChartStyle = .lightweight
   }
   ```

2. **Add Default State Tests:**
   - Snapshot tests for calm home view
   - Unit tests for state management
   - Accessibility tests for default state

### Near-Term Actions (P1)

1. **Implement State Persistence:**
   - Add `UserDefaults` or `AppStorage` for view mode preference
   - Respect user's last chosen state on app launch
   - Add settings UI for default preference

2. **Enhance Loading States:**
   - Add calm loading indicators
   - Implement skeleton screens for async data
   - Ensure loading states follow calm principles

3. **Error State Design:**
   - Design calm error presentation
   - Progressive disclosure for error details
   - Recovery options with minimal disruption

### Long-Term Actions (P2)

1. **Configuration UI:**
   - Settings panel for calm surface preferences
   - Customization options for power users
   - Documentation of calm principles

2. **Analytics Integration:**
   - Track calm vs. expanded state usage
   - Measure progressive disclosure effectiveness
   - Monitor user preference patterns

3. **Design System Integration:**
   - Formalize calm surface patterns in design system
   - Create reusable calm components
   - Document best practices

## Implementation Plan

### Phase 1: Configuration Centralization (1-2 days)
- [ ] Create `CalmSurfaceConfiguration` struct
- [ ] Replace magic numbers with constants
- [ ] Document configuration options
- [ ] Update existing code to use configuration

### Phase 2: State Management (2-3 days)
- [ ] Implement state persistence
- [ ] Add user preference settings
- [ ] Test session restoration
- [ ] Update default behaviors

### Phase 3: Testing & Quality (2-3 days)
- [ ] Add snapshot tests for default states
- [ ] Implement unit tests for configuration
- [ ] Add accessibility tests
- [ ] Verify animation behaviors

## Success Criteria

**Phase 1 Complete:**
- ✅ All calm surface defaults centralized in configuration
- ✅ No magic numbers in animation or timing
- ✅ Configuration is well-documented

**Phase 2 Complete:**
- ✅ User preferences persist across sessions
- ✅ Default view mode is configurable
- ✅ State management is reliable and tested

**Phase 3 Complete:**
- ✅ Comprehensive test coverage for defaults
- ✅ All accessibility requirements met
- ✅ Animation behaviors are consistent and smooth

## Monitoring & Maintenance

**Metrics to Track:**
- User preference for default view mode
- Time spent in calm vs. expanded states
- Feature discovery rates
- User satisfaction with progressive disclosure

**Maintenance Tasks:**
- Quarterly review of calm surface defaults
- User testing for new default configurations
- Documentation updates for new features
- Regression testing for default behaviors

## Conclusion

The current calm surface implementation follows good progressive disclosure principles but would benefit from:
1. **Centralized configuration** for easier maintenance
2. **State persistence** to respect user preferences  
3. **Comprehensive testing** to prevent regressions
4. **Enhanced loading/error states** for better UX

The audit reveals a solid foundation that can be improved with systematic configuration management and user preference support.