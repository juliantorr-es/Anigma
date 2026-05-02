# API Governance Policy Templates (td-34082e)

## Task Status

**Task ID:** td-34082e  
**Epic:** td-f9576a (Compilation Surface Reduction)  
**Date:** 2026-04-14  
**Status:** IN PROGRESS - Policy Framework & Templates Complete

## Reference Policy Document

**Location:** `FOUNDATION_API_GOVERNANCE_ANALYSIS.md`  
**Canonical Status:** Source of truth for API governance violations and enforcement

This document provides templates for TD policy enforcement and agent decision-making.

## Core Governance Principles

### 1. Foundation Module Stability

**Policy:** Public APIs in foundation modules (AnigmaCore, CapsuleCore, etc.) must be stable and minimal.

**Template: Foundation API Freeze Notice**

```
## API Freeze for {ModuleName} (Foundation)

**Module:** {ModuleName}  
**Classification:** Foundation  
**Status:** API FREEZE - No public API changes without approval

### Current Public Surface
- Public types: {Count}
- Public functions: {Count}
- Public properties: {Count}

### Governance Rule
1. Any public API addition requires architecture review
2. Any public API removal requires deprecation notice (1 quarter notice)
3. Any public API modification must maintain backward compatibility

### Approval Authority
- Tier 1 (minor fixes): TD maintainer approval
- Tier 2 (enhancements): Architecture review board
- Tier 3 (breaking changes): Full team discussion + migration plan

Violations are tracked in FOUNDATION_API_GOVERNANCE_ANALYSIS.md
```

### 2. Feature Module Contracts-First Design

**Policy:** Feature modules must separate contract/DTO surface from implementation.

**Template: Feature Module Split Verification**

```
## Contract-Implementation Split Verification

**Module:** {FeatureModuleName}

### Public Surface Audit
- [ ] Contracts/protocols in {ContractsModule}
- [ ] DTOs defined in contracts module
- [ ] Implementation in {ImplementationModule}
- [ ] No implementation leaking to contracts
- [ ] Consumers depend only on contracts

### Dependency Check
```bash
# Verify no implementation imports in contract consumers
rg "import.*Implementation" {ContractsModule}/
# Should return: 0 results
```

### Passes Split Test: ✅/❌
```

### 3. Module Dependency Governance

**Policy:** Modules must respect fan-out budgets and tiered dependencies.

**Template: Dependency Governance Review**

```
## Dependency Governance Review

**Module:** {ModuleName}  
**Tier:** {V0|V1|V2|V3|V4}

### Budget Compliance
- Current fan-out: {Count}
- Budget: {MaxForTier}
- Status: ✅ Compliant / ❌ Exceeds

### Dependency Chain Validation
```bash
# Check for circular dependencies
swift build --diagnostic-format json 2>&1 | jq '.[] | select(.type == "error")'
```

### Governance Checklist
- [ ] No circular dependencies
- [ ] Dependencies meet fan-out budget
- [ ] Foundation modules only used for contracts, not implementation
- [ ] Feature modules don't depend on other features unexpectedly

### Recommendation
[Approve / Request changes / Escalate to architecture]
```

## Application Examples

### Example 1: AnyCodable Canonicalization (Already Applied)

**Governance Principle Applied:** "Foundation Module Stability"

**Policy:** AnyCodable is a foundation primitive in AnigmaPrimitives. Duplicate definitions violate this.

**Application:**
```
## AnyCodable Foundation Governance (td-dbdb41)

**Module:** AnigmaPrimitives (Foundation)  
**Component:** AnyCodable type

### Governance Violation
- 8 duplicate public AnyCodable definitions found in:
  - PDFExporterKit
  - RLMModule
  - AnigmaGeminiBridge
  - [etc.]

### Remediation
- Consolidated all duplicates to canonical AnigmaPrimitives.AnyCodable
- Updated consumers to use typealias to canonical type
- Eliminated type confusion and Signal 4 risk

### Validation
- ✅ All affected modules build successfully
- ✅ No API changes to consumers
- ✅ Compilation surface reduced

### Governance Compliance
- Foundation module now has single, stable AnyCodable definition
- Duplicates eliminated
- Policy enforced for future development
```

### Example 2: HarmoniaV2Surface Split (In Progress)

**Governance Principle Applied:** "Feature Module Contracts-First Design"

**Policy:** HarmoniaV2Surface mixes contracts with implementation, violating separation rule.

**Application:**
```
## HarmoniaV2Surface Contract Split (td-f846b9)

**Module:** HarmoniaV2Surface (Feature/Bottleneck)  
**Issue:** Mixed contracts and implementation in single module

### Current Violation
- Protocol definitions + DTOs mixed with LocalAppClient
- Database machinery exposed in public API
- Governance machinery exposed in public API

### Remediation Plan
1. Create HarmoniaV2Contracts module
2. Move protocols and DTOs there
3. HarmoniaV2Surface depends on HarmoniaV2Contracts
4. Update consumers to depend only on contracts if DTO-only

### Expected Governance Compliance
- Contracts module: minimal, stable public surface
- Implementation module: can evolve independently
- Consumers: clear dependency on contracts vs. implementation

### Validation Method
- Build HarmoniaV2Contracts independently ✅
- All DTO consumers compile with Contracts-only dependency ✅
- Implementation consumers have full dependency graph ✅
```

## TD Policy Enforcement Templates

### Template 1: Weekly API Governance Scan

**Purpose:** Automated check for governance violations

```markdown
## Weekly API Governance Scan - {DATE}

### Foundation Modules Check
```bash
for module in AnigmaCore CapsuleCore ContractsCore AnigmaPrimitives; do
  echo "### $module"
  grep -A 100 "\.target.*name.*$module" Package.swift | grep dependencies
done
```

### Result Summary
- ✅/❌ No new public APIs in foundation modules
- ✅/❌ All foundation module dependencies meet policy
- ✅/❌ No duplicates of foundation types detected

### Action Items
- [List any violations]
- [Assign TD tasks for remediation]

---
```

### Template 2: Public API Review Gate

**Purpose:** Approval process for public API changes in foundation modules

```markdown
## API Governance Review: {Module}.{API}

**Submitted by:** {Author}  
**Module:** {Module}  
**Classification:** {Foundation|Feature|Standard}  
**Change Type:** {New|Modification|Removal}

### Proposed Change
```swift
// Old (if modification/removal)
{OldAPI}

// New (if new/modification)
{NewAPI}
```

### Governance Impact
- **Fan-in affected:** {Count} modules
- **Backward compatibility:** {Yes|No|Partial}
- **Breaking:** {Yes|No}

### Governance Review
- [ ] Minimal public surface? (Foundation only)
- [ ] Backward compatible? (If applicable)
- [ ] Documented? 
- [ ] Tested?

### Approval Authority
- Tier 1 (bug fixes): ✅ Self-approve
- Tier 2 (enhancements): ⬜ Architecture review required
- Tier 3 (breaking): ⬜ Full team consensus required

**Approved by:** {Reviewer}  
**Approval Date:** {Date}
```

## Policy Enforcement Checklist

### For Each Foundation Module (Quarterly)

- [ ] Audit public API surface
- [ ] Check for new duplicates or aliases
- [ ] Verify no implementation leaking into contracts
- [ ] Validate fan-out against budget
- [ ] Document any exceptions

### For Each Feature Module Split (On-Demand)

- [ ] Contract module created/verified
- [ ] DTOs moved to contracts module
- [ ] Implementation isolated in feature module
- [ ] Consumers updated to contract-only dependency
- [ ] Builds validate cleanly

### For Fan-Out Budget Changes

- [ ] Module tier verified
- [ ] New dependencies justified
- [ ] Budget impact calculated
- [ ] TD task created if exceeds budget
- [ ] Architecture approval obtained

## Governance Artifacts

### Created This Session

1. **This document:** API_GOVERNANCE_POLICY_TEMPLATES.md
2. **Templates:** Policy enforcement templates (above)
3. **Checklists:** Governance compliance checklists

### Related Canonical Documents

- **FOUNDATION_API_GOVERNANCE_ANALYSIS.md** - Source of truth for violations
- **SIGNAL4_VULNERABILITY_MATRIX.md** - Module vulnerability tiers
- **ANYCODABLE_CONSOLIDATION_EVIDENCE.md** - Governance application example
- **HARMONIAV2SURFACE_SPLIT_EVIDENCE.md** - Contracts-first example

### To Create for Full Implementation

- [ ] Automated API scanning script (`scan_api_governance.sh`)
- [ ] TD policy document with enforcement rules
- [ ] Weekly governance scan results template
- [ ] API review gate checklist for PRs
- [ ] Module governance status dashboard

## Usage Instructions for Agents

### Using These Templates

1. **Foundation API Changes:**
   - Use "Foundation API Freeze Notice" template
   - Check FOUNDATION_API_GOVERNANCE_ANALYSIS.md for current status
   - Apply "Tier 1/2/3" approval process based on change type

2. **Feature Module Splits:**
   - Use "Contract-Implementation Split Verification" template
   - Follow "Contracts-First Design" principle
   - Reference td-f846b9 example (HarmoniaV2Surface)

3. **Dependency Changes:**
   - Use "Dependency Governance Review" template
   - Check FAN_OUT_BUDGETS_ENFORCEMENT.md for budgets
   - Reference SIGNAL4_VULNERABILITY_MATRIX.md for module tier

4. **API Governance Violations:**
   - Use "Weekly API Governance Scan" template
   - Check FOUNDATION_API_GOVERNANCE_ANALYSIS.md for precedent
   - Create TD task following "Tier 1/2/3" approval process

### Decision Framework

**Question:** Should I add a new public API to {Module}?

```
1. What tier is this module?
   - Foundation (AnigmaCore, etc.)? → Tier 2 approval minimum
   - Feature (RLMModule, etc.)? → Tier 1 approval + contract review
   - Standard? → Tier 1 approval

2. Does this exceed fan-out budget?
   - Check FAN_OUT_BUDGETS_ENFORCEMENT.md
   - If yes → Split module or defer feature

3. Is this a duplicate of existing API elsewhere?
   - Search FOUNDATION_API_GOVERNANCE_ANALYSIS.md
   - If yes → Use existing, create alias, don't duplicate

4. Proceed with:
   - Tier 1: Self-review + standard checklist
   - Tier 2: Architecture review + rationale
   - Tier 3: Team discussion + migration plan
```

## Success Criteria

Policy is successfully enforced when:

✅ **Baseline state (current):**
- 8 duplicate AnyCodable types consolidated (td-dbdb41)
- Policy templates documented and available

✅ **Target state (after implementation):**
- No new duplicates of foundation types
- All feature modules follow contracts-first design
- All modules within fan-out budgets
- Weekly governance scans show 0 violations
- API changes require appropriate approval tier

## Next Steps

1. ✅ Create and document policy templates (completed this session)
2. ⬜ Create automated API governance scanning script
3. ⬜ Implement TD enforcement rules
4. ⬜ Run first weekly governance scan
5. ⬜ Create child tasks for violations found

---

**Status:** IN PROGRESS - Templates & Policies Complete  
**Evidence Level:** Framework complete, automation pending  
**Blocker:** None - ready to implement  
**Validation Needed:** Automated scan results + TD policy enforcement

**For Next Agent:** Start with "Usage Instructions" section above. Reference templates when making API changes or reviewing module structures.
