# Proof: Executable Consolidation Audit

**Date:** 2026-05-05
**Mode:** advisory
**Focus:** anigmad

## Summary Stats
- **Swift Files Scanned:** 268
- **Total Findings:** 770
- **New Findings (Unbaselined):** 770

### By Severity
- critical: 82
- high: 65
- medium: 239
- low: 384
- info: 0

### By Confidence
- high_confidence: 116
- medium_confidence: 465
- low_confidence: 189

### By Category
- logging_destination: 384
- singleton_global_state: 178
- shutdown_and_exit: 51
- daemon_ipc_binding: 31
- argv_and_environment: 30
- process_identity: 28
- test_mode_detection: 15
- entrypoint_lifecycle: 14
- working_directory: 12
- detached_tasks_and_lifetime: 11
- signal_handling: 8
- bundle_resource_lookup: 5
- temporary_paths: 3

## Top 20 Highest-Risk Findings
1. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDependency.swift:1143` [shutdown_and_exit]
   - **Snippet:** `fatalError("\(#file):\(#line) - Illegal call of deprecated function \(#function)")`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

2. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDependency.swift:1148` [shutdown_and_exit]
   - **Snippet:** `fatalError("\(#file):\(#line) - Illegal call of deprecated function \(#function)")`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

3. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:347` [entrypoint_lifecycle]
   - **Snippet:** `/// considers a target to be an executable target if its directory contains a `main.swift`, `main.m`, `main.c`,`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

4. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:386` [entrypoint_lifecycle]
   - **Snippet:** `/// considers a target to be an executable target if its directory contains a `main.swift`, `main.m`, `main.c`,`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

5. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:608` [entrypoint_lifecycle]
   - **Snippet:** `/// is expected to either have a source file named `main.swift`, `main.m`, `main.c`, or `main.cpp`, or a source`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

6. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:609` [entrypoint_lifecycle]
   - **Snippet:** `/// file that contains the `@main` keyword.`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

7. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:663` [entrypoint_lifecycle]
   - **Snippet:** `/// is expected to either have a source file named `main.swift`, `main.m`, `main.c`, or `main.cpp`, or a source`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

8. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:664` [entrypoint_lifecycle]
   - **Snippet:** `/// file that contains the `@main` keyword.`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

9. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:720` [entrypoint_lifecycle]
   - **Snippet:** `/// is expected to either have a source file named `main.swift`, `main.m`, `main.c`, or `main.cpp`, or a source`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

10. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/Target.swift:721` [entrypoint_lifecycle]
   - **Snippet:** `/// file that contains the `@main` keyword.`
   - **Review Question:** Does this code hijack the main thread or define a competing entrypoint?

11. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDescription.swift:400` [process_identity]
   - **Snippet:** `if let index = CommandLine.arguments.firstIndex(of: "-handle") {`
   - **Review Question:** Does this code read process identity even though anigmad is now the only entrypoint?

12. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDescription.swift:401` [process_identity]
   - **Snippet:** `if let handle = Int(CommandLine.arguments[index + 1], radix: 16) {`
   - **Review Question:** Does this code read process identity even though anigmad is now the only entrypoint?

13. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDescription.swift:406` [process_identity]
   - **Snippet:** `if let optIdx = CommandLine.arguments.firstIndex(of: "-fileno") {`
   - **Review Question:** Does this code read process identity even though anigmad is now the only entrypoint?

14. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDescription.swift:407` [process_identity]
   - **Snippet:** `if let jsonOutputFileDesc = Int32(CommandLine.arguments[optIdx + 1]) {`
   - **Review Question:** Does this code read process identity even though anigmad is now the only entrypoint?

15. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/PackageDescriptionSerializationConversion.swift:358` [shutdown_and_exit]
   - **Snippet:** `fatalError("should not be reached")`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

16. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackageDescription/ContextModel.swift:42` [process_identity]
   - **Snippet:** `var args = Array(ProcessInfo.processInfo.arguments[1...]).makeIterator()`
   - **Review Question:** Does this code read process identity even though anigmad is now the only entrypoint?

17. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackagePlugin/Plugin.swift:139` [shutdown_and_exit]
   - **Snippet:** `exit(1)`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

18. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackagePlugin/Plugin.swift:237` [shutdown_and_exit]
   - **Snippet:** `exit(0)`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

19. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackagePlugin/Plugin.swift:314` [shutdown_and_exit]
   - **Snippet:** `exit(0)`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

20. `ExternalResearch/swift-tooling/swift-package-manager/Sources/Runtimes/PackagePlugin/Plugin.swift:357` [shutdown_and_exit]
   - **Snippet:** `exit(0)`
   - **Review Question:** Can this code call exit/fatalError and kill the whole daemon?

## Recommendation
⚠️ **WARNING:** These findings are advisory review candidates, not automatically proven bugs. They indicate places where code *thinks* it is still a standalone process.

We recommend creating a targeted TD (Tech Debt) task to manually review the top critical/high findings, especially focusing on `exit(`, `fatalError(`, socket binding, and `CommandLine.arguments` within the `anigmad` target.
