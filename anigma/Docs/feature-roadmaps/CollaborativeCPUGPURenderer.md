# Collaborative CPU/GPU Renderer Feature Roadmap

## Overview
A daemon-first collaborative rendering system that intelligently allocates work between CPU and GPU based on system load, user archetypes, and task requirements. The system provides honest metrics about resource utilization, intelligent prompts for optimization, and evolves based on user behavior.

## Core Principles

1. **Daemon-First Execution**: Frontends schedule work, daemon executes it
2. **Honest Communication**: Quantifiable explanations for resource decisions  
3. **User Archetype Learning**: Assessment with behavioral adaptation over time
4. **System Efficiency First**: Metrics that matter for Anigma's work, not just FPS
5. **Immediate Full Rollout**: Complete implementation from day one

## Architecture Analysis

### Current Strengths to Leverage
- **Daemon-First Architecture**: Frontends schedule, daemon executes (perfect for heavy rendering)
- **User Preference Systems**: AppStore, SessionState, search feedback learning
- **Job Queue Infrastructure**: UnifiedJobQueue with persistence, retry, quarantine
- **Notification Systems**: Toast, TUI event bus, progress streaming
- **Metrics Collection**: TelemetryCore with privacy enforcement, performance budgets
- **Dashboard Architecture**: CompassView with card-based layout and pinned actions
- **Behavioral Learning**: InstitutionalLearningSystem with consent management
- **Preset Systems**: ExportPresetComponent with platform-specific configurations

### Key Gaps to Address
1. No user archetype system with honest assessment
2. No archetype-based dashboard presets with customization
3. No frontend closure prompts with quantifiable explanations
4. No job queue diagnostics with adaptive error handling
5. No collaborative CPU/GPU rendering with system efficiency metrics

## Implementation Plan: 4 Agents, 4 Rounds

### Round 1: Foundation & Core Systems (2 weeks)

#### Agent 1: User Archetype System with Learning
**Files to Create:**
- `./anigma/Packages/UserArchetypes/ArchetypeAssessmentEngine.swift` - Assessment logic
- `./anigma/Packages/UserArchetypes/ArchetypeQuestionnaire.swift` - Assessment questions
- `./anigma/Packages/UserArchetypes/ArchetypeRecommendationEngine.swift` - Recommendation logic
- `./anigma/Sources/AnigmaCLI/Onboarding/ArchetypeAssessmentView.swift` - TUI assessment UI

**Key Tasks:**
1. Define archetypes: PowerUser, CasualUser, BatteryConscious, QualityFocused, ComputeFocused
2. Create honest assessment questionnaire with transparent scoring
3. Implement recommendation engine: "Based on your answers, we recommend X archetype"
4. Build TUI assessment view integrated into existing onboarding flow
5. Add skip option and direct archetype selection

#### Agent 2: Archetype Storage & Integration
**Files to Create/Modify:**
- `./anigma/Packages/UserArchetypes/ArchetypePreferences.swift` - Preference storage
- `./anigma/Sources/AnigmaCLI/CLIConfiguration.swift` - Extend CLIPreferences
- `./anigma/Packages/UserArchetypes/ArchetypeMigration.swift` - Migration tools
- `./anigma/Sources/AnigmaAppMac/AppStore.swift` - Extend for archetype state

**Key Tasks:**
1. Extend CLIPreferences with archetype data and assessment results
2. Create ArchetypePreferences struct with learning data
3. Implement migration for existing users
4. Integrate with AppStore for macOS app state management
5. Add archetype display in user profile/settings

#### Agent 3: Privacy & Consent Systems
**Files to Create:**
- `./anigma/Packages/UserArchetypes/ArchetypeLearningConsent.swift` - Consent management
- `./anigma/Packages/UserArchetypes/ArchetypeDataAnonymizer.swift` - Data anonymization
- `./anigma/Packages/UserArchetypes/ArchetypeLearningOptIn.swift` - Opt-in UI

**Key Tasks:**
1. Create consent system for behavioral data collection
2. Implement local-first data storage with encryption
3. Build anonymization system for aggregated learning
4. Create opt-in UI for "help Anigma development" features
5. Integrate with existing InstitutionalLearningSystem

#### Agent 4: Dashboard Preset Foundation
**Files to Create:**
- `./anigma/Packages/DashboardPresets/DashboardPresetComponent.swift` - Preset system
- `./anigma/Packages/DashboardPresets/ArchetypeDashboardPresets.swift` - Archetype presets
- `./anigma/Packages/DashboardPresets/DashboardLayoutEngine.swift` - Layout engine

**Key Tasks:**
1. Create DashboardPresetComponent based on ExportPresetComponent pattern
2. Define archetype-specific dashboard presets
3. Implement layout engine using Bauhaus grid system
4. Create preset storage and management
5. Build preset application system

### Round 2: Intelligent Resource Management & Learning (2 weeks)

#### Agent 1: Frontend Closure Prompts
**Files to Create:**
- `./anigma/Packages/ResourceOptimization/HeavyJobDetector.swift` - Job complexity analysis
- `./anigma/Packages/ResourceOptimization/QuantifiableExplanationGenerator.swift` - Explanation engine
- `./anigma/Packages/ResourceOptimization/FrontendClosurePrompt.swift` - Prompt UI
- `./anigma/Packages/ResourceOptimization/NotificationConversion.swift` - Notification system

**Key Tasks:**
1. Implement heavy job detection with complexity scoring
2. Create quantifiable explanation generator with time estimates
3. Build prompt UI with "convert to notifications for today" option
4. Implement notification system for converted prompts
5. Integrate with existing Toast and TUI notification systems

#### Agent 2: Behavioral Learning Engine
**Files to Create:**
- `./anigma/Packages/UserArchetypes/ArchetypeBehaviorLearner.swift` - Behavioral learning
- `./anigma/Packages/UserArchetypes/PreferenceEvolutionTracker.swift` - Preference tracking
- `./anigma/Packages/UserArchetypes/DefaultSuggestionEngine.swift` - Default suggestions

**Key Tasks:**
1. Implement behavioral learning from user decisions
2. Create preference evolution tracking with consistency detection
3. Build default suggestion engine: "You always choose X, make it default?"
4. Implement learning data storage with privacy controls
5. Integrate with existing MusicLearningIntegration patterns

#### Agent 3: Dashboard Customization System
**Files to Create:**
- `./anigma/Packages/DashboardPresets/DashboardCustomizationUI.swift` - Customization UI
- `./anigma/Packages/DashboardPresets/DashboardLayoutCustomizer.swift` - Layout customizer
- `./anigma/Packages/DashboardPresets/DashboardMetricSelector.swift` - Metric selector
- `./anigma/Sources/AnigmaAppMac/Dashboards/CustomizableDashboardView.swift` - Customizable dashboard

**Key Tasks:**
1. Create dashboard customization UI with drag-and-drop layout
2. Implement metric selector with archetype-based recommendations
3. Build layout customizer using Bauhaus grid system
4. Create customizable dashboard view that supports both presets and custom layouts
5. Implement customization storage and sharing

#### Agent 4: Collaborative Renderer Foundation
**Files to Create:**
- `./anigma/Packages/CollaborativeRenderer/CollaborativeRenderWorker.swift` - Daemon worker
- `./anigma/Packages/CollaborativeRenderer/GPUMonitoringService.swift` - GPU load detection
- `./anigma/Native/Shims/include/anigma_collaborative_render.h` - Native interface

**Key Tasks:**
1. Create CollaborativeRenderWorker for daemon execution
2. Implement GPU monitoring with compute load detection
3. Build native C++ foundation with SIMD optimization
4. Register worker with JobRegistry in daemon startup
5. Create basic work allocation algorithms

### Round 3: System Efficiency & Advanced Features (2 weeks)

#### Agent 1: System Efficiency Metrics
**Files to Create:**
- `./anigma/Packages/SystemEfficiency/SystemEfficiencyMetrics.swift` - Efficiency metrics
- `./anigma/Packages/SystemEfficiency/TaskRelevanceScorer.swift` - Metric relevance
- `./anigma/Packages/SystemEfficiency/ArchetypeMetricPrioritizer.swift` - Archetype prioritization
- `./anigma/Sources/AnigmaAppMac/Dashboards/SystemEfficiencyDashboard.swift` - Efficiency dashboard

**Key Tasks:**
1. Define system efficiency metrics relevant to Anigma's work
2. Implement task relevance scoring for different job types
3. Create archetype-based metric prioritization
4. Build SystemEfficiencyDashboard with honest disclosures
5. Integrate with existing transparency dashboards

#### Agent 2: Job Queue Diagnostics & Error Handling
**Files to Create:**
- `./anigma/Packages/JobDiagnostics/JobQueueDiagnosticService.swift` - Queue diagnostics
- `./anigma/Packages/JobDiagnostics/JobResumeRestartEngine.swift` - Resume/restart logic
- `./anigma/Packages/JobDiagnostics/AdaptiveErrorCommunicator.swift` - Context-aware errors
- `./anigma/Packages/JobDiagnostics/JobQuarantineManager.swift` - Intelligent quarantine

**Key Tasks:**
1. Implement job queue diagnostics with corruption detection
2. Create resume/restart logic with checkpoint validation
3. Build adaptive error communication based on user archetype
4. Implement intelligent quarantine with user options
5. Integrate with existing UnifiedJobQueue and error systems

#### Agent 3: Advanced Collaborative Rendering
**Tasks:**
1. Implement extensive SIMD optimization for CPU rendering
2. Create dynamic quality/performance tradeoff algorithms
3. Build memory bandwidth optimization for unified memory
4. Implement thermal-aware performance scaling
5. Create cross-device performance profiles

#### Agent 4: Integration & Polish
**Tasks:**
1. Integrate all systems with existing daemon services
2. Implement comprehensive testing framework
3. Create user documentation and guides
4. Build performance benchmarking suite
5. Implement governance and receipt integration

### Round 4: Testing, Optimization & Release (2 weeks)

#### Agent 1: Comprehensive Testing
**Tasks:**
1. Create automated testing for archetype assessment system
2. Implement behavioral learning validation tests
3. Build performance testing across Apple Silicon variants
4. Create integration testing with all daemon services
5. Implement user experience testing

#### Agent 2: Performance Optimization
**Tasks:**
1. Performance optimization for M1 baseline
2. Untapped performance exploration for M3 Ultra
3. Battery life optimization
4. Thermal management refinement
5. Memory usage optimization

#### Agent 3: Documentation & User Guidance
**Tasks:**
1. Create user guides for archetype selection and learning
2. Document resource optimization features and benefits
3. Create troubleshooting guides for rendering issues
4. Build API documentation for integration
5. Create performance tuning documentation

#### Agent 4: Release Preparation
**Tasks:**
1. Final integration testing with all frontends
2. Performance validation on M1 baseline and M3 Ultra
3. Create release documentation and changelog
4. Implement monitoring and alerting for production
5. Prepare for immediate full rollout

## Key Technical Architecture

### User Archetype System
```swift
enum UserArchetype: String, Codable {
    case powerUser          // "Get it done fast, I'll close apps"
    case casualUser         // "Keep it simple, don't bother me"
    case batteryConscious   // "Save my battery, I'm mobile"
    case qualityFocused     // "Make it perfect, take your time"
    case computeFocused     // "Keep GPU free for ML work"
}
```

### Honest Assessment During Onboarding
- **Assessment Flow**: Welcome → Assessment Questions → Recommendation → Choice
- **Transparent Scoring**: Show how answers map to archetypes
- **Skip Options**: Skip assessment, choose directly, or use default
- **Final Choice**: "Based on your answers, we recommend X, but you can choose differently"

### Local-First Learning with Opt-In
- **Default**: All behavioral data stays local, encrypted
- **Opt-In**: Users can choose to help Anigma development with anonymized, aggregated data
- **Consent Management**: Clear disclosure of data usage, never sold/shared
- **Revocable**: Users can change consent anytime

### Always Prompt for Heavy Jobs
- **Detection**: Job complexity analysis with GPU load consideration
- **Quantifiable Explanations**: "X time with frontend, Y time without (Z times faster)"
- **Notification Conversion**: Option to convert prompts to notifications for rest of day
- **Evolution**: Learns from user choices, suggests defaults for consistent behavior

### Archetype-Based Dashboard Presets
- **Power User**: Performance metrics, throughput, resource utilization
- **Quality Focused**: Visual quality, accuracy, fidelity metrics
- **Battery Conscious**: Power efficiency, thermal metrics, battery impact
- **Compute Focused**: GPU headroom, compute task compatibility
- **Customizable**: Users can customize layouts and metrics

### Collaborative Rendering Architecture
- **GPU Load Detection**: Monitor compute vs. graphics workload
- **Adaptive Allocation**: Shift work between CPU and GPU based on load
- **SIMD Optimization**: ARM NEON/Apple Accelerate for CPU rendering
- **System Efficiency Metrics**: Honest metrics about resource utilization effectiveness

## Integration Points

### With Existing Onboarding
```swift
// Extend OnboardingCoordinator
func addArchetypeAssessmentStep() async {
    // Insert after welcome, before cloud provider configuration
    let assessmentView = ArchetypeAssessmentView()
    let result = await assessmentView.runAssessment()
    
    if let archetype = result {
        await configuration.setArchetype(archetype)
    }
}
```

### With CompassView Dashboard
```swift
// Add efficiency dashboard tab
extension CompassView {
    func addEfficiencyDashboardTab() -> some View {
        TabView {
            CustomizableDashboardView(
                availablePresets: DashboardPresetComponent.archetypePresets,
                userArchetype: appStore.userProfile?.selectedArchetype
            )
            .tabItem {
                Label("Efficiency", systemImage: "gauge")
            }
        }
    }
}
```

### With Job Submission
```swift
// Enhanced job submission with resource optimization
extension UnifiedJobQueue {
    func submitRenderingJob(_ request: RenderingJobRequest) async throws -> JobID {
        // Check for heavy job and show prompt if needed
        if await resourceOptimizer.isHeavyJob(request) {
            let prompt = await resourceOptimizer.createPrompt(for: request)
            let decision = await promptPresenter.showPrompt(prompt)
            
            // Apply user decision
            request.optimization = decision.optimization
            
            // Record for learning
            await archetypeManager.recordDecision(decision)
        }
        
        // Submit with diagnostics
        return try await submit(
            type: .collaborativeRender,
            payload: request,
            diagnostics: .enabled,
            errorHandling: .adaptive(userProfile: await archetypeManager.currentProfile())
        )
    }
}
```

## Success Criteria

### User Archetype System
- Users can select archetype during onboarding with honest assessment
- System learns and adapts based on behavior over time
- Archetype-specific optimizations are applied correctly
- Users can manually override or change archetype

### Intelligent Resource Optimization
- Frontend closure prompts appear for genuinely heavy jobs
- Quantifiable explanations are accurate and helpful
- Users understand tradeoffs and can make informed decisions
- Notification conversion works correctly

### Job Queue Diagnostics & Error Handling
- Queue corruption is detected and can be repaired/resumed
- Adaptive error communication matches user archetype
- Users get appropriate recovery options based on failure type
- Quarantine system works for problematic jobs

### System Efficiency Metrics
- Metrics are relevant to Anigma's work (not just FPS)
- Dashboard shows task-appropriate metrics
- Honest disclosure of system capabilities and limitations
- Efficiency improvements are measurable and meaningful

### Collaborative Rendering
- GPU compute load detection works accurately
- Adaptive work allocation improves system efficiency
- Performance meets M1 baseline and explores M3 Ultra potential
- Visual quality is preserved for appropriate tasks

## Open Questions for Implementation

1. **Assessment Question Design**: Focus on specific scenarios or general preferences?
2. **Opt-In Timing**: When to offer anonymized data sharing (immediate, after usage, based on consistency)?
3. **Notification Conversion Default**: One-day, this week, or permanent until changed?
4. **Default Suggestion Frequency**: After N consistent choices or based on confidence threshold?
5. **Dashboard Preset Switching**: Quick switching or deliberate settings change?

## Timeline & Resources
- **Total Duration**: 8 weeks (4 rounds × 2 weeks each)
- **Team Size**: 4 agents working in parallel
- **Release Strategy**: Immediate full rollout after completion
- **Testing Strategy**: Comprehensive testing in Round 4, visual regression testing during release

## Dependencies
- Existing daemon architecture (JobQueue, JobRegistry, WorkerPool)
- Current onboarding system (OnboardingCoordinator, TUI views)
- Dashboard architecture (CompassView, Bauhaus design system)
- Telemetry and metrics systems (TelemetryCore, performance budgets)
- Behavioral learning infrastructure (InstitutionalLearningSystem)

## Risks & Mitigation
- **Performance Overhead**: Extensive profiling and optimization in Rounds 2-3
- **User Experience Complexity**: Gradual feature introduction with clear explanations
- **Integration Challenges**: Leverage existing patterns and extension points
- **Testing Coverage**: Comprehensive automated testing framework
- **Release Stability**: Immediate full rollout with monitoring and rollback capability

---

**Last Updated**: 2025-01-27  
**Status**: Planned  
**Priority**: High  
**Estimated Effort**: 8 person-weeks  
**Target Release**: After 4-round implementation  
**Primary Contact**: Implementation Team  
**Related Documents**: ARCHITECTURE_VISUAL_GUIDE.md, UI_ARCHITECTURE_ANALYSIS.md, PerformanceBudgets.md