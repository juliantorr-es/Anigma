# 09: Security & Hardening: Technical Protocol
- **ASAN/TSAN Integration**: SwiftPM build flags automatically inject `-sanitize=address,thread` on test targets.
- **Memory Fences**: Explicit memory management for shared-memory (SHM) buffers with the daemon kernel.
- **Access Control**: All `System` access to `World` is gated by the component type-registry; arbitrary component injection is blocked.
