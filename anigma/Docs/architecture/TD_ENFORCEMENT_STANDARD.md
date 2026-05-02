# TD Enforcement Standard: The Anigma Way

To maintain architectural integrity, all TD issues must be "Ruthless." Soft, vague, or non-auditable tasks are prohibited.

## 1. Task Definition Requirements
Every task must include:
- **Contract Anchor**: Reference a specific `AnigmaContract` or boundary.
- **Hardware Lane**: Specify `.inference`, `.evidence`, or `.control`.
- **Serialization Check**: Explicitly mention "Serialization Wall" or "Zero-Copy" requirements.
- **Evidence Requirement**: Define what evidence artifact must be produced (e.g., "Blake3 Receipt").

## 2. Prohibited Content
- **Vague verbs**: "Improve", "Optimize", "Cleanup", "Refactor" (without a target contract).
- **Ad-hoc state**: Tasks that don't produce a validated artifact or evidence receipt.
- **Leaky boundaries**: Any task that implies passing raw Swift objects (Arrays/Strings) into `.inference` lanes.

## 3. Enforcement Policy
- Non-compliant issues will be purged without warning.
- Epics must be decomposed into Contract-First tasks before implementation begins.
- "Completed" means verified by a contract-aware test suite and evidence receipt.

---
*Authorized by Gemini CLI - 2026-04-23*

## 4. The "No-Stub" Mandate
The Anigma Production Standard has zero tolerance for "half-assed" implementations.
- **Stubs & Mocks**: Prohibited in production boundaries. A contract implementation must be either complete (native-wired, evidence-linked) or absent. 
- **Wrappers**: "Passthrough" wrappers that merely relay raw payloads without enforcing the Serialization Wall or invariant validation are considered architectural defects.
- **Placeholder Receipts**: The use of `ContractReceipt.placeholder()` is restricted to initial bootstrap; all production-ready contracts must generate real, cryptographically-linked receipts.
- **Exit Gate**: Any pull request or mission containing "TODO", "FIXME", or "stub" at a contract boundary will be rejected by the verifier lane.

---
