# Repository Atlas Bootstrap Proof

Date: 2026-05-05

## Files Created
- `scripts/anigma_build_repo_atlas.py`
- `scripts/anigma_context_query.py`
- `scripts/atlas/__init__.py`
- `scripts/atlas/common.py`
- `scripts/atlas/swift_indexer.py`
- `scripts/atlas/cpp_indexer.py`
- `scripts/atlas/metal_indexer.py`
- `scripts/atlas/script_indexer.py`
- `scripts/atlas/manifest_indexer.py`
- `Docs/atlas/README.md`
- `Docs/schemas/repo-atlas.schema.json`
- `Docs/proofs/repository-atlas-bootstrap-2026-05-05.md`

## Files Modified
- `scripts/anigma_build_repo_atlas.py`
- `scripts/anigma_context_query.py`
- `scripts/atlas/manifest_indexer.py`
- `scripts/atlas/common.py`

## Commands Run
- `python3 -m py_compile scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py`
- `python3 -m py_compile scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py scripts/atlas/*.py`
- `python3 scripts/anigma_build_repo_atlas.py`
- `python3 scripts/anigma_context_query.py --symbol RuntimeAuthority`
- `python3 scripts/anigma_context_query.py "anigmad process configuration"`
- `python3 scripts/anigma_context_query.py "where is the Metal resize kernel used?"`
- `python3 scripts/anigma_context_query.py --risk daemon_ipc_binding`
- `python3 scripts/anigma_context_query.py --language metal`
- `python3 scripts/anigma_context_query.py --language cpp`
- `python3 scripts/anigma_context_query.py --native-dependency pdfium`
- `python3 scripts/anigma_context_query.py --check`
- `python3 scripts/anigma_diagnose.py validate --task-id td-atlas-001 --command true`

## Exit Codes
- `python3 -m py_compile scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py`: `0`
- `python3 -m py_compile scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py scripts/atlas/*.py`: `0`
- `python3 scripts/anigma_build_repo_atlas.py`: `0`
- `python3 scripts/anigma_context_query.py --symbol RuntimeAuthority`: `0`
- `python3 scripts/anigma_context_query.py "anigmad process configuration"`: `0`
- `python3 scripts/anigma_context_query.py "where is the Metal resize kernel used?"`: `0`
- `python3 scripts/anigma_context_query.py --risk daemon_ipc_binding`: `0`
- `python3 scripts/anigma_context_query.py --language metal`: `0`
- `python3 scripts/anigma_context_query.py --language cpp`: `0`
- `python3 scripts/anigma_context_query.py --native-dependency pdfium`: `0`
- `python3 scripts/anigma_context_query.py --check`: `0`
- `python3 scripts/anigma_diagnose.py validate --task-id td-atlas-001 --command true`: `0`

## Results
- Indexed files: 7525
- Indexed Swift files: 3078
- Indexed C/C++/ObjC files: 1736
- Indexed Metal files: 2
- Indexed scripts: 192
- Targets: 0
- Symbols by language:
  - Swift: 40366
  - C/C++/ObjC: 30733
  - Metal: 3
  - Script: 155
- Entrypoints: 272
- Authorities/executors/registries/workers: 308
- Metal kernels: 3
- Native dependencies detected: 4835
- Bridge references: 22
- Imported risk findings: 1052

## Example Query Outputs
- `--symbol RuntimeAuthority` returned `RuntimeAuthority` from `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/System/RuntimeAuthority.swift`
- `anigmad process configuration` returned daemon-adjacent configuration and authority files, including `Docs/proofs/td-cleanup-003-batch-002-process-configuration-alignment.md` and `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Configuration/ConfigWatcher.swift`
- `where is the Metal resize kernel used?` returned Metal and bridge context including `anigma/Sources/PlatformAdapters/Shaders.metal` and `anigma/Packages/SaturationKit/Sources/SaturationKit/SaturatedSearch.metal`
- `--risk daemon_ipc_binding` returned IPC-related hits, including `anigma/App/MacApp/ConnectionMonitor.swift` and `anigma/Packages/AnigmaPrimitives/MCPTransport.swift`
- `--language metal` returned `anigma/Sources/PlatformAdapters/Shaders.metal` and `anigma/Packages/SaturationKit/Sources/SaturationKit/SaturatedSearch.metal`
- `--language cpp` returned native capsule sources including `anigma/Native/Kernel/src/kernel_context.cpp` and `anigma/Native/Shims/src/compression/anigma_compression_capsule.cpp`
- `--native-dependency pdfium` returned PDFium vendor paths and related proof docs

## Notes
- Source files remain canonical.
- Atlas is derived evidence only.
- Production Swift was not changed by this task.
- Production C/C++/Metal was not changed by this task.
