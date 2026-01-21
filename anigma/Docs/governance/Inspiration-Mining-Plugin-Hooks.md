# Inspiration Mining Protocol Plugin Hooks

> **Purpose:** Define OpenCode plugin enforcement hooks for Inspiration Mining Protocol  
> **Authority:** HarmoniaCLI (governance authority) with coordination from AnigmaCore (type authority)  
> **Version:** 1.0  
> **Status:** Active

---

## 1. Overview

This specification defines plugin hooks that enforce Inspiration Mining Protocol by intercepting OpenCode tool calls and validating required artifacts before allowing pattern adoption activities. The hooks ensure protocol compliance by:

- **Artifact Validation**: Verifying pattern cards, ADRs, roadmap entries exist
- **Boundary Enforcement**: Checking type authority compliance and module boundaries  
- **NextTool Routing**: Directing agents through proper extraction vs. adoption workflows
- **Receipt Integration**: Ensuring all pattern activities generate proper receipts
- **Error Handling**: Providing rollback procedures for failed operations

---

## 2. Plugin Schema and Execution Points

### 2.1 Hook Registration

```typescript
interface PluginHook {
  toolName: string;
  phase: 'before' | 'after' | 'error';
  validator: ValidatorFunction;
  errorMessage: string;
  nextTool?: string;
}

interface ValidatorContext {
  agent: string;
  sessionID: string;
  messageID: string;
  args: Record<string, any>;
  ledgerPath: string;
}

type ValidatorFunction = (ctx: ValidatorContext) => ValidationResult;

interface ValidationResult {
  ok: boolean;
  message?: string;
  requiredArtifacts?: string[];
  nextTool?: string;
  blockExecution?: boolean;
}
```

### 2.2 Execution Points

| Tool | Phase | Purpose | Validation Logic |
|------|-------|---------|-----------------|
| `apply_patch` | before | Block direct mutation without protocol artifacts | Check for pattern card, ADR, roadmap entries |
| `generate_patch` | before | Ensure pattern adoption follows extraction | Verify inspiration_patterns tool ran first |
| `propose_patch` | before | Validate proposal contains phase ID and criteria | Check phaseId, acceptanceRefs, riskNotes |
| `inspiration_patterns` | after | Generate extraction receipt | Record pattern registry and backlog artifacts |
| `validate_patch` | before | Ensure governance gates include pattern validation | Check type authority and contract compliance |

---

## 3. Artifact Validation Rules

### 3.1 Required Artifact Paths

```typescript
const REQUIRED_ARTIFACTS = {
  patternCard: (patternId: string) => `Inspiration/patterns/${patternId}.md`,
  adr: (adrNumber: string) => `Docs/ADR/${adrNumber}-pattern-${patternId}.md`,
  roadmapEntry: () => `Docs/roadmap/pattern-backlog.md`,
  contractArtifact: (surfaceName: string) => `Docs/governance/contract-artifacts/${surfaceName}.md`,
  typeAuthorityMap: () => `Docs/governance/type-authority-map.json`,
  inspirationRegistry: () => `Docs/patterns/pattern-registry.json`,
  phaseContract: (phaseId: string) => `Docs/governance/phases/${phaseId}.md`
};
```

### 3.2 Pattern Card Validation

**Required Sections:**
- Source Information (repository, anchor, extraction date, agent)
- Intent (problem statement)
- Forces (constraints/requirements)
- Boundary (Core vs Capability layer)
- Contract Surface (public APIs, types, protocols)
- Failure Modes (known scenarios and mitigation)
- What It Replaces (existing approach superseded)
- Where It Lives in Anigma (target module/structure)
- Acceptance Tests (validation requirements)
- Rollout Strategy (implementation timeline)

**Validation Logic:**
```typescript
function validatePatternCard(content: string): ValidationResult {
  const requiredSections = [
    'Source Information', 'Intent', 'Forces', 'Boundary',
    'Contract Surface', 'Failure Modes', 'What It Replaces',
    'Where It Lives in Anigma', 'Acceptance Tests', 'Rollout Strategy'
  ];

  const missing = requiredSections.filter(section => 
    !content.includes(`## ${section}`)
  );

  return {
    ok: missing.length === 0,
    message: missing.length > 0 ? `Missing sections: ${missing.join(', ')}` : undefined,
    requiredArtifacts: missing.map(s => `Pattern card section: ${s}`)
  };
}
```

### 3.3 ADR Validation

**Required Structure:**
- Status, Date, Supersedes, Superseded by headers
- Context (issue description)
- Decision (proposed change)
- Rationale with alternatives considered
- Consequences (positive, negative, neutral)
- Migration plan with timeline

**Validation Logic:**
```typescript
function validateADR(content: string, patternId: string): ValidationResult {
  const hasBoundaryImpact = content.toLowerCase().includes('boundary');
  const hasTypeAuthority = content.toLowerCase().includes('type authority');
  const hasContractAuthority = content.toLowerCase().includes('contract authority');
  const hasMigrationPath = content.includes('## Migration');

  if (hasBoundaryImpact || hasTypeAuthority) {
    if (!hasContractAuthority) {
      return {
        ok: false,
        message: 'ADR with boundary/type impact must address contract authority',
        requiredArtifacts: ['Contract authority section in ADR']
      };
    }
  }

  if (!hasMigrationPath) {
    return {
      ok: false,
      message: 'ADR must include migration plan',
      requiredArtifacts: ['Migration plan section in ADR']
    };
  }

  return { ok: true };
}
```

### 3.4 Type Authority Check

**Conflict Detection:**
```typescript
function validateTypeAuthority(
  proposedTypes: Record<string, string>,
  existingMap: TypeAuthorityMap
): ValidationResult {
  const conflicts = Object.entries(proposedTypes).filter(([typeName, authority]) => {
    const existing = existingMap[typeName];
    return existing && existing !== authority;
  });

  if (conflicts.length > 0) {
    return {
      ok: false,
      message: `Type authority conflicts: ${conflicts.map(([t]) => t).join(', ')}`,
      requiredArtifacts: conflicts.map(([t, e, p]) => 
        `Type ${t}: existing=${e}, proposed=${p}`
      ),
      blockExecution: true
    };
  }

  return { ok: true };
}
```

---

## 4. NextTool Routing Logic

### 4.1 Extraction Workflow

When agents attempt pattern adoption without extraction:

```typescript
function routeToExtraction(ctx: ValidatorContext): ValidationResult {
  const hasInspirationReceipt = checkLedgerForReceipt(
    ctx.ledgerPath, 
    'generation', 
    'inspiration_patterns',
    ctx.sessionID
  );

  if (!hasInspirationReceipt) {
    return {
      ok: false,
      message: 'Must run inspiration_patterns tool before adopting patterns',
      nextTool: 'inspiration_patterns',
      blockExecution: true
    };
  }

  return { ok: true };
}
```

### 4.2 Adoption Workflow

Sequential progression through pattern adoption:

```typescript
const ADOPTION_SEQUENCE = [
  'inspiration_patterns',    // Extract patterns from source
  'inspect_repo',           // Inspect current codebase state
  'generate_patch',         // Create changes for pattern adoption
  'propose_patch',          // Attach phase ID and acceptance criteria
  'validate_patch',         // Run governance gates
  'apply_patch'            // Apply validated changes
];

function validateAdoptionSequence(
  currentTool: string,
  sessionID: string,
  ledgerPath: string
): ValidationResult {
  const toolIndex = ADOPTION_SEQUENCE.indexOf(currentTool);
  if (toolIndex <= 0) return { ok: true };

  const requiredTools = ADOPTION_SEQUENCE.slice(0, toolIndex);
  const missingTools = requiredTools.filter(tool => 
    !checkLedgerForReceipt(ledgerPath, null, tool, sessionID)
  );

  if (missingTools.length > 0) {
    return {
      ok: false,
      message: `Missing required tool sequence: ${missingTools.join(' → ')}`,
      nextTool: missingTools[0],
      blockExecution: true
    };
  }

  return { ok: true };
}
```

---

## 5. Receipt Integration

### 5.1 Inspiration Mining Receipt Schema

```typescript
interface InspirationMiningReceipt {
  kind: 'pattern_extraction' | 'pattern_adoption' | 'pattern_validation';
  ts: string;
  meta: { agent: string; sessionID: string; messageID: string };
  patternId?: string;
  artifacts: {
    patternCard?: string;
    adr?: string;
    roadmapEntry?: string;
    contractArtifact?: string;
    typeAuthorityUpdate?: boolean;
  };
  phaseId?: string;
  acceptanceRefs?: string[];
  governanceChecks: {
    typeAuthority: boolean;
    contractAuthority: boolean;
    dependencyBoundaries: boolean;
    swift6Compliance: boolean;
  };
  ok: boolean;
  detail?: any;
}
```

### 5.2 Receipt Generation

**Pattern Extraction Receipt:**
```typescript
function generateExtractionReceipt(
  ctx: ValidatorContext,
  patternCount: number,
  registryPath: string,
  roadmapPath: string
): void {
  const receipt: InspirationMiningReceipt = {
    kind: 'pattern_extraction',
    ts: new Date().toISOString(),
    meta: { agent: ctx.agent, sessionID: ctx.sessionID, messageID: ctx.messageID },
    artifacts: {
      inspirationRegistry: registryPath,
      roadmapEntry: roadmapPath
    },
    governanceChecks: {
      typeAuthority: true,  // Extraction doesn't modify types
      contractAuthority: true,  // Extraction doesn't modify contracts
      dependencyBoundaries: true,
      swift6Compliance: true
    },
    ok: true,
    detail: { patternCount, registryPath, roadmapPath }
  };

  appendReceipt(ctx.ledgerPath, receipt);
}
```

**Pattern Adoption Receipt:**
```typescript
function generateAdoptionReceipt(
  ctx: ValidatorContext,
  patternId: string,
  phaseId: string,
  acceptanceRefs: string[],
  artifacts: string[]
): void {
  const receipt: InspirationMiningReceipt = {
    kind: 'pattern_adoption',
    ts: new Date().toISOString(),
    meta: { agent: ctx.agent, sessionID: ctx.sessionID, messageID: ctx.messageID },
    patternId,
    phaseId,
    acceptanceRefs,
    artifacts: {
      patternCard: artifacts.find(a => a.includes('pattern-card')),
      adr: artifacts.find(a => a.includes('ADR')),
      contractArtifact: artifacts.find(a => a.includes('contract-artifacts')),
      typeAuthorityUpdate: artifacts.some(a => a.includes('type-authority'))
    },
    governanceChecks: {
      typeAuthority: artifacts.some(a => a.includes('type-authority')),
      contractAuthority: artifacts.some(a => a.includes('contract')),
      dependencyBoundaries: true,  // Validated by gates
      swift6Compliance: true      // Validated by gates
    },
    ok: true,
    detail: { adoptedArtifacts: artifacts }
  };

  appendReceipt(ctx.ledgerPath, receipt);
}
```

---

## 6. Error Handling and Rollback Procedures

### 6.1 Error Classification

```typescript
enum ErrorType {
  MISSING_PATTERN_CARD = 'missing_pattern_card',
  MISSING_ADR = 'missing_adr',
  TYPE_AUTHORITY_CONFLICT = 'type_authority_conflict',
  CONTRACT_VIOLATION = 'contract_violation',
  SEQUENCE_VIOLATION = 'sequence_violation',
  PHASE_MISMATCH = 'phase_mismatch',
  GATE_FAILURE = 'gate_failure'
}

interface ErrorRecovery {
  errorType: ErrorType;
  rollbackTool?: string;
  recoverySteps: string[];
  preventReapply: boolean;
}
```

### 6.2 Rollback Matrix

| Error Type | Rollback Tool | Recovery Steps | Prevent Reapply |
|------------|---------------|-----------------|-----------------|
| MISSING_PATTERN_CARD | `rollback_last_apply` | 1. Create pattern card 2. Re-propose patch | Yes |
| MISSING_ADR | `rollback_last_apply` | 1. Create ADR 2. Re-propose patch | Yes |
| TYPE_AUTHORITY_CONFLICT | `rollback_last_apply` | 1. Resolve type conflict 2. Update authority map 3. Re-propose | Yes |
| CONTRACT_VIOLATION | `rollback_last_apply` | 1. Update contract artifact 2. Re-validate | Yes |
| SEQUENCE_VIOLATION | None | 1. Run missing tools in sequence | No |
| PHASE_MISMATCH | None | 1. Update proposal with correct phase ID | No |
| GATE_FAILURE | `rollback_last_apply` | 1. Fix gate failures 2. Re-validate | Yes |

### 6.3 Rollback Procedure

```typescript
async function handlePatternAdoptionFailure(
  ctx: ValidatorContext,
  errorType: ErrorType,
  details: string
): Promise<ValidationResult> {
  const recovery = ERROR_RECOVERY_MATRIX[errorType];
  const rollbackAvailable = recovery.rollbackTool && hasRecentApply(ctx.ledgerPath, ctx.sessionID);

  // Generate quarantine receipt if rollback is needed
  if (rollbackAvailable && recovery.preventReapply) {
    await quarantinePatch(ctx, errorType, details);
  }

  // Perform rollback if available
  if (rollbackAvailable && recovery.rollbackTool) {
    await executeTool(recovery.rollbackTool, { ledgerPath: ctx.ledgerPath });
  }

  return {
    ok: false,
    message: `${errorType}: ${details}. Recovery: ${recovery.recoverySteps.join(' → ')}`,
    nextTool: rollbackAvailable ? undefined : recovery.recoverySteps[0] as string,
    blockExecution: true
  };
}
```

---

## 7. Integration with Existing Governance

### 7.1 Type Authority Integration

The hooks extend to existing type authority map by validating:
- New type definitions don't shadow Core types
- Authority boundaries are respected in capability modules
- Type authority map is updated when new types are introduced

### 7.2 Contract Authority Integration

Contract artifacts are validated through:
- Surface definitions in `Docs/governance/contract-artifacts/`
- Cross-boundary interface compliance
- Adapter pattern usage for external integrations

### 7.3 HarmoniaCLI Integration

All pattern adoption activities must:
- Use `Scripts/harmonia.sh` for governance operations
- Follow receipt chain through `validate_patch` gates
- Generate Accessum artifacts for provenance tracking

### 7.4 Phase Contract Integration

Pattern adoption proposals must include:
- Valid `phaseId` referencing active phase contract
- `acceptanceRefs` citing specific acceptance criteria
- `riskNotes` addressing security and architectural concerns

---

## 8. Implementation Notes

### 8.1 Plugin Registration

Hooks are registered through OpenCode plugin configuration and intercept tool calls at specified phases. Each hook receives tool arguments and execution context.

### 8.2 Performance Considerations

- Artifact validation uses file existence checks initially
- Content validation is performed only when files exist
- Type authority validation uses caching for repeated checks
- Receipt generation is asynchronous to avoid blocking tool execution

### 8.3 Debugging Support

Failed hook executions generate diagnostic receipts including:
- Validation failure details
- Required artifact paths
- Suggested recovery steps
- Hook execution timing information

### 8.4 Extensibility

The hook system supports:
- Custom validators for domain-specific requirements
- Additional artifact types as patterns evolve
- Integration with future governance mechanisms

---

## 9. References

- **Inspiration Mining Protocol**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/Inspiration-Mining-Protocol.md`
- **Type Authority Map**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/type-authority-map.json`
- **Phase Contracts**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/phases/`
- **Contract Artifacts**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/contract-artifacts/`
- **ADR Template**: `/Users/user/Developer/GitHub/Anigma/Docs/ADR/0000-template.md`
- **Agent Contract**: `/Users/user/Developer/GitHub/Anigma/AGENTS.md`
- **OpenCode Plugin System**: `/Users/user/Developer/GitHub/Anigma/agent_tools.md`

---

*This specification ensures that inspiration mining activities are properly governed, auditable, and compliant with Anigma's architectural boundaries while maintaining flexibility to extract valuable patterns from external sources.*
