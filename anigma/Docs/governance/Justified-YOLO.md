# Justified YOLO Enforcement

Mutating commands must now pass through the single choke point in `Scripts/harmonia.sh`, which calls `Scripts/justified_yolo_guard.py` before it executes any sanctioned Harmonia mutation. The guard enforces:

1. **Sanctioned mechanism** – only the configured Harmonia wrapper commands (`harmonia.patch.apply`, `harmonia.deps.*`, `harmonia.db.migrate`, etc.) are auto-approved.
2. **Structured justification** – every mutation must supply `justification.json` that satisfies the schema (`intent`, `workflow_step`, `scope`, `preconditions`, `safety`, `rollback`, `evidence`, `autopilot`).
3. **Job-scoped token** – `.anigma/autopilot/token.json` must exist, be unexpired, match the current branch, and allow the requested mechanism + scope globs.
4. **Scope/precondition checks** – the guard ensures declared paths stay within token scope, the working tree is clean, the base commit matches `HEAD`, and required validation receipts already exist.
5. **Rollback/evidence pins** – only allowlisted rollback methods are permitted, and receipts/logs must be emitted into `.anigma/receipts`/`.anigma/logs`.

Read-only harmonia commands continue to run without justification or token. The guard writes a stub receipt for every allowed mutation so later workflow steps can insist on its presence.

### Autopilot tokens

Tokens live in `.anigma/autopilot/token.json` and look like:

```json
{
  "token_id": "ap-2025-12-24T18-22:00Z-9f3c",
  "branch": "fix/xcode-full-build",
  "allowed_mechanisms": ["harmonia.patch.apply", "harmonia.validate.target"],
  "scope_globs": ["Sources/ContractsCore/**", "Sources/HarmoniaCLI/**"],
  "minted_at": "2025-12-24T18:22:00Z",
  "expires_at": "2025-12-24T19:22:00Z"
}
```

Any mutating command without a valid token falls back to the human approval path.

### Justification examples

Place the required justification JSON under `.anigma/yolo/justification.json` (or point `Scripts/harmonia.sh` to a different path via `--justification` or `ANIGMA_YOLO_JUSTIFICATION`). `harmonia.sh` automatically stamps the current `HEAD` into `preconditions.base_commit`/`rollback.target` by running `Scripts/justified_yolo_stamp.py`, so you don’t need to edit those fields manually. The `autopilot.token_id` field is also refreshed from `.anigma/autopilot/token.json` before each mutating call, and `scope.paths` lists the precise files the mutation touches so the guard can enforce bounding.

### Receipts and logs

Receipts and logs from each allowed mutation land under `.anigma/receipts/` and `.anigma/logs/` respectively. Downstream workflow steps (Migrator, Integrator) can assert that the receipt exists before continuing.

### Short term

For now, the guard only enforces patch/apply/deps/db workflows (via `Scripts/harmonia.sh`) while leaving the rest of the approval system intact. Later phases can extend the allowlist, add token minting helpers, and tighten scope enforcement once this choke point proves reliable.
