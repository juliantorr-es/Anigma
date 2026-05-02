# 00: Doctrine Status Matrix

| Claim | Source | Enforcement Script | Runtime Proof | Current Status | Owning TD |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **No Cycles** | 01, 04 | `validate_no_cycles.py` | `anigma proof` bundle | Implemented | td-8f2e57 |
| **No `@_exported`** | 01, 04 | `validate_exported_imports.py` | `anigma proof` bundle | Partially Implemented | td-8f2e57 |
| **No Implicit Media Copies** | 06, 12 | `MaterializationGate` tests | `ZeroCopyProof` logs | Partially Implemented | TBD |
| **Strict Tiering** | 01 | `validate_tiers.py` | `anigma proof` bundle | Designed | TBD |
| **Codable IPC Only for Control** | 14 | N/A | Log inspection | Partially Implemented | TBD |
| **ASAN/TSAN CI Gate** | 09 | `swift test --sanitize=...` | Build Logs | Implemented | TBD |
