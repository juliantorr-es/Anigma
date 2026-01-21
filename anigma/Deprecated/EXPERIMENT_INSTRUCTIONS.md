# Phase 4B Swift 6 Experiment

## Objective
Run a small governed migration with dynamic trust scoring enabled, observe trajectories, and verify the control system behaves sanely.

## Preparation Complete
✅ Database initialized with v2 schema
✅ Governance mode set to 'governed'
✅ Initial trust scores set for engines
✅ Monitoring script created

## Experiment Steps

### 1. Start Trust Scheduler
```bash
# The scheduler should auto-start in governed mode
# Verify with:
./monitor_experiment.sh
```

### 2. Run Small Migration Batch
```bash
# Create Swift 6 migration tasks
harmonia scout run swift6 --create-tasks

# Process a small batch (5 tasks max)
harmonia swift6 step --count 5
```

### 3. Immediate Inspection
After running the batch, immediately check:
```bash
./monitor_experiment.sh
```

### 4. Critical Checks
Look for these patterns:

**✅ GOOD (System working):**
- Trust scores change by ±5-15 points max
- Each score change has corresponding security events
- No double-punishment (same event counted once)
- Blocked operations show clear chain: event → trust change → capability decision

**❌ BAD (System broken):**
- Scores nosedive >20 points in one session
- Score changes without visible security events
- Same subject recalculated hourly with zero change
- Trust events feeding back into scoring

### 5. If System is Broken
1. Check for double-punishment: `SELECT * FROM security_events WHERE engine_id = 'migration-engine-1' ORDER BY created_at DESC;`
2. Check trust history: `SELECT * FROM trust_history WHERE subject_id = 'migration-engine-1' ORDER BY created_at DESC;`
3. Verify `trust_calculated_at` updates on every score change
4. Check that trust events are excluded from scoring

### 6. If System is Working
1. Let scheduler run for 24 hours
2. Observe score drift (should be gradual, not spiky)
3. Tune weights in `TrustScoringConfig.swift` based on evidence
4. Expand experiment scope

## Success Criteria
- You can answer "what was blocked and why" from CLI/logs alone
- Trust scores settle into stable ranges over multiple sessions
- When governance blocks something, you can point to specific doctrine/weight

## Notes
- This is instrumentation validation, not optimization
- Focus on verifying the control loop is closed and sane
- Tuning comes after verification
