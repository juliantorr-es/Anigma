# 10: CI/CD & Validator Protocols: Execution Path
1. **Pre-flight**: `anigma doctor`
2. **Apply**: `patch` / `replace`
3. **Validate**:
    - `python3 Scripts/validate_exported_imports.py`
    - `python3 Scripts/validate_no_cycles.py .build/anigma-package.json`
    - `python3 Scripts/validate_tiers.py`
    - `swift test --filter <AffectedTarget>`
4. **Finalize**: `anigma proof` (bundles diagnostics)
