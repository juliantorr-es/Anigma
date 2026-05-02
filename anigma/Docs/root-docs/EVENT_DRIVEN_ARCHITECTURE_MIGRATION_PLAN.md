# Event-Driven Architecture Migration Plan

## Current State Analysis

### Total Modules in Anigma
- **Total targets**: 125 modules
- **Event-driven modules**: 1 (AnigmaEvents)
- **Modules using AnigmaEvents**: 1 (HarmoniaModule)

### Current Event-Driven Adoption

#### ✅ **Already Event-Driven**
1. **AnigmaEvents** (NEW) - Event bus and event definitions
   - Provides foundation for event-driven architecture
   - Includes workflow, job, and system events
   - Type-safe event handling

#### 🔄 **Hybrid (Partially Event-Driven)**
1. **HarmoniaModule** - Now depends on AnigmaEvents
   - Has AnigmaEvents as a dependency
   - Ready to publish events (not yet implemented)
   - Still uses direct dependencies for some operations

#### ❌ **Not Yet Event-Driven**
1. **AnigmaCLITUI** - Removed HarmoniaModule dependency
   - No longer depends on HarmoniaModule
   - Could subscribe to Harmonia events
   - Currently uses TUIEventBus internally

2. **AnigmaCLIEventing** - Has its own event system
   - Uses TUIEventBus for internal communication
   - Could integrate with AnigmaEvents

3. **AnigmaDaemonCore** - Core daemon functionality
   - Many dependencies including HarmoniaModule
   - Could benefit from event-driven job management

4. **AnigmaAgents** - Agent-based modules
   - Depends on HarmoniaModule
   - Could use events for agent communication

5. **AnigmaCorporate** - Enterprise features
   - Depends on HarmoniaModule
   - Could use events for workflow notifications

6. **RLMModule** - Research and learning module
   - Depends on HarmoniaModule
   - Could use events for data processing updates

## Migration Priority Assessment

### Priority 1: High Impact, Low Effort (Quick Wins)

#### 1. **AnigmaCLITUI Integration** (Estimated: 2-4 hours)
**Current State**: Removed HarmoniaModule dependency, uses TUIEventBus
**Opportunity**: Subscribe to Harmonia workflow/job events
**Benefits**: 
- Real-time UI updates without direct dependencies
- Better separation of concerns
- More responsive user interface

**Implementation**:
```swift
// In ChatPresenter or similar
let subscription = await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    await TUIEventBus.shared.publish(.tokenReceived(token: event.token))
}
```

#### 2. **HarmoniaModule Event Publishing** (Estimated: 4-6 hours)
**Current State**: Has AnigmaEvents dependency but doesn't use it
**Opportunity**: Publish workflow and job events
**Benefits**:
- Decouples workflow execution from UI
- Enables multiple UI clients (TUI, CLI, GUI)
- Better observability

**Implementation**:
```swift
// In workflow execution methods
await sharedEventBus.publish(
    WorkflowStartedEvent(
        workflowId: workflow.id,
        workflowName: workflow.name
    )
)

// When processing jobs
await sharedEventBus.publish(
    JobTokenEvent(
        jobId: job.id,
        token: token
    )
)
```

### Priority 2: Medium Impact, Medium Effort

#### 3. **AnigmaDaemonCore Event Integration** (Estimated: 8-12 hours)
**Current State**: Direct dependencies on many modules
**Opportunity**: Use events for job lifecycle management
**Benefits**:
- Decouples job execution from daemon core
- Enables distributed job processing
- Better fault tolerance

**Implementation**:
- Publish job events instead of direct callbacks
- Subscribe to system events for coordination

#### 4. **AnigmaAgents Event Communication** (Estimated: 6-10 hours)
**Current State**: Depends on HarmoniaModule
**Opportunity**: Use events for agent-workflow communication
**Benefits**:
- Agents can react to workflow events
- Workflows can trigger agent actions via events
- More flexible agent orchestration

### Priority 3: Long-term, Strategic

#### 5. **Cross-Process Event Bus** (Estimated: 2-3 days)
**Current State**: In-process event bus only
**Opportunity**: Extend to support distributed systems
**Benefits**:
- Daemon and client can communicate via events
- Enables cloud-based processing
- Better scalability

**Implementation**:
- Add network transport layer
- Implement event persistence
- Add event replication

#### 6. **Event-Driven Capsules** (Estimated: Ongoing)
**Current State**: Capsules use direct function calls
**Opportunity**: Capsules publish events on completion
**Benefits**:
- Better composition of capsules
- Event-based pipeline processing
- More flexible workflows

## Migration Roadmap

### Phase 1: Foundation (Already Complete) ✅
- [x] Create AnigmaEvents module
- [x] Define core event types (workflow, job, system)
- [x] Implement event bus infrastructure
- [x] Break HarmoniaModule ↔ AnigmaCLITUI circular dependency

### Phase 2: Core Integration (Next 1-2 Weeks)
- [ ] Integrate HarmoniaModule event publishing
- [ ] Connect AnigmaCLITUI to Harmonia events
- [ ] Add event logging and monitoring
- [ ] Document event contracts and usage patterns

### Phase 3: Extended Integration (Next 2-4 Weeks)
- [ ] Integrate AnigmaDaemonCore with event bus
- [ ] Add AnigmaAgents event subscribers
- [ ] Implement event-based job queue
- [ ] Add event persistence for reliability

### Phase 4: Advanced Features (Next 1-2 Months)
- [ ] Cross-process event communication
- [ ] Event-driven capsule composition
- [ ] WebSocket event streaming
- [ ] Event analytics and metrics

## Module-by-Module Analysis

### Modules That Could Publish Events

| Module | Potential Events | Priority |
|--------|------------------|----------|
| HarmoniaModule | WorkflowStarted, WorkflowProgress, WorkflowCompleted, JobToken, JobCompleted | 1 |
| AnigmaDaemonCore | JobSubmitted, JobStatusUpdated, SystemNotification | 2 |
| AnigmaAgents | AgentActionStarted, AgentActionCompleted, AgentError | 3 |
| ContextumModule | ProcessingStarted, ProcessingCompleted, DataUpdated | 3 |
| RLMModule | ResearchTaskStarted, ResearchTaskCompleted, ModelUpdated | 3 |

### Modules That Could Subscribe to Events

| Module | Potential Subscriptions | Priority |
|--------|--------------------------|----------|
| AnigmaCLITUI | JobToken, WorkflowProgress, SystemNotification | 1 |
| AnigmaCLIEventing | All Harmonia events | 2 |
| AnigmaDaemonCore | SystemError, SystemNotification | 2 |
| AnigmaAgents | WorkflowCompleted, JobCompleted | 3 |
| AnigmaCorporate | WorkflowCompleted, SystemNotification | 3 |

## Benefits of Full Migration

### 1. **Architectural Benefits**
- ✅ **Decoupled modules**: No direct dependencies between UI and backend
- ✅ **Better testability**: Modules can be tested in isolation
- ✅ **Improved maintainability**: Clear event contracts
- ✅ **Enhanced scalability**: Events can be processed asynchronously

### 2. **Functional Benefits**
- ✅ **Real-time updates**: Multiple UI clients can react to same events
- ✅ **Better observability**: All actions are visible through events
- ✅ **Flexible composition**: New features can be added via event subscribers
- ✅ **Resilience**: Failed event processing can be retried

### 3. **Performance Benefits**
- ✅ **Asynchronous processing**: Events can be processed in background
- ✅ **Load balancing**: Multiple subscribers can handle same events
- ✅ **Caching opportunities**: Events can be cached and replayed
- ✅ **Batch processing**: Events can be processed in batches

## Implementation Strategy

### Step 1: Event Definition
For each module that needs to publish events:
1. Define event types in AnigmaEvents
2. Ensure events are strongly typed
3. Document event contracts

### Step 2: Event Publishing
For modules that publish events:
1. Replace direct calls with event publishing
2. Maintain backward compatibility during transition
3. Add logging for event publishing

### Step 3: Event Subscribing
For modules that subscribe to events:
1. Add event subscriptions in initialization
2. Handle events appropriately
3. Implement error handling for event processing

### Step 4: Testing
1. Unit test event publishing
2. Unit test event handling
3. Integration test event flows
4. Performance test event throughput

## Risk Assessment

### Low Risk Areas
- ✅ **AnigmaEvents module**: Foundation is solid
- ✅ **HarmoniaModule integration**: Low risk, high benefit
- ✅ **AnigmaCLITUI integration**: Simple subscription pattern

### Medium Risk Areas
- ⚠️ **AnigmaDaemonCore**: Complex dependencies
- ⚠️ **Cross-process events**: Network reliability concerns
- ⚠️ **Event persistence**: Data consistency challenges

### Mitigation Strategies
1. **Incremental migration**: One module at a time
2. **Dual-write pattern**: Keep old mechanisms during transition
3. **Comprehensive testing**: Unit, integration, and load testing
4. **Monitoring**: Track event processing metrics
5. **Rollback plan**: Ability to revert to direct calls if needed

## Success Metrics

### Quantitative Metrics
- ✅ **Number of modules using events**: Target 20% in 1 month, 50% in 3 months
- ✅ **Reduction in circular dependencies**: Target 75% reduction
- ✅ **Event processing latency**: Target < 100ms for 95% of events
- ✅ **Event throughput**: Target 1000 events/second

### Qualitative Metrics
- ✅ **Developer satisfaction**: Easier to add new features
- ✅ **Test coverage**: Higher testability of modules
- ✅ **Code maintainability**: Clearer module boundaries
- ✅ **System reliability**: Better error handling and recovery

## Recommendations

### Immediate Actions (Next Sprint)
1. **Complete HarmoniaModule event publishing**
2. **Integrate AnigmaCLITUI with Harmonia events**
3. **Add event logging and monitoring**
4. **Document event patterns and best practices**

### Short-term Actions (Next 2-3 Sprints)
1. **Integrate AnigmaDaemonCore with event bus**
2. **Add event persistence for critical events**
3. **Implement event-based job queue**
4. **Create event testing framework**

### Long-term Actions (Next 3-6 Months)
1. **Extend event bus to cross-process communication**
2. **Implement event-driven capsule composition**
3. **Add WebSocket event streaming**
4. **Build event analytics dashboard**

## Conclusion

The Anigma project has successfully laid the foundation for event-driven architecture with the creation of the AnigmaEvents module and the resolution of the circular dependency between HarmoniaModule and AnigmaCLITUI.

**Current Adoption**: ~1% (1 out of 125 modules actively using events)
**Target Adoption**: 50% within 3 months, 80% within 6 months

**Estimated Effort**:
- **Phase 2 (Core Integration)**: 2-3 weeks, 2-3 developers
- **Phase 3 (Extended Integration)**: 4-6 weeks, 3-4 developers
- **Phase 4 (Advanced Features)**: 8-12 weeks, 2-3 developers

**ROI**: High - Event-driven architecture will significantly improve maintainability, scalability, and testability of the Anigma codebase.

The foundation is in place. Now it's time to build on it systematically, module by module, to create a truly event-driven, decoupled architecture.
