# Swift 6 Policy vs Language Truths: Explicit Documentation

## Purpose

This document explicitly separates **policy choices** from **language truths** to ensure our enforcement system remains honest about what is required by Swift 6 versus what we choose to enforce for architectural reasons.

## Language Truths (Swift 6 Requirements)

### 1. Static Variables Are Never Actor-Isolated
**Language Truth**: `static var` properties are **never** protected by actor isolation, regardless of where they are declared.

**Swift Documentation**: 
- "Static members of actors are not actor-isolated"
- Global actor isolation only applies to instance members
- Static properties create global mutable state

**Enforcement**: All `static var` without global actor isolation is flagged as violation.

### 2. Global Actor Isolation Is a General Mechanism
**Language Truth**: Any actor can serve as a global actor (`@GlobalActor`), not just `@MainActor`.

**Swift Documentation**:
- Global actor serializes access to its members from any concurrency context
- Custom global actors can be defined for specific isolation needs
- Multiple global actors can coexist

**Policy Choice**: We allow any global actor isolation, not just `@MainActor`.

### 3. Strict Concurrency Checking Is All-or-Nothing
**Language Truth**: Swift 6 language mode enables strict concurrency checking by default.

**Swift Documentation**:
- Swift 6 = "Swift 5 + strict concurrency = complete" by default
- `-Xswiftc -strict-concurrency=complete` and `SWIFT_STRICT_CONCURRENCY=complete` are equivalent
- Settings affect diagnostic behavior: warnings → errors

**Enforcement**: We require both command-line and environment variable validation.

### 4. @preconcurrency Is Import-Only Bridge
**Language Truth**: `@preconcurrency` is specifically designed for importing legacy dependencies only.

**SE-0337 Documentation**:
- `@preconcurrency import` suppresses concurrency warnings for imported types
- Does not apply to declarations within the module
- Intended as incremental migration tool, not general silencer

**Enforcement**: Only import statements may use `@preconcurrency`.

### 5. Macro Expansion Can Hide Violations
**Language Truth**: SwiftSyntax sees macro usages, not expanded generated code.

**Swift Documentation**:
- Macros operate at compile time to generate code
- Expanded code may contain patterns not visible in source
- `-Xfrontend -dump-macro-expansions` shows generated code

**Enforcement**: We analyze both macro definitions and expanded output where possible.

## Policy Choices (Architectural Decisions)

### 1. Allow Custom Global Actors
**Policy**: `@MyCustomGlobalActor` is permitted for static isolation.

**Rationale**:
- Some domains need specific isolation semantics
- MainActor is not the only valid global actor
- Allows architectural flexibility while maintaining safety

**Documentation**: Explicitly stated as policy choice, not language requirement.

### 2. "Any Branch Violation" Policy for #if
**Policy**: Any conditional compilation branch containing violations fails build.

**Alternative**: `activeConfigOnly` - Only currently active config violations fail.

**Rationale**:
- Prevents "it's only in DEBUG" from metastasizing
- Treats dead code as architecturally relevant
- Can be relaxed to `activeConfigOnly` for practicality

**Documentation**: Policy can be toggled via CI configuration.

### 3. Time-Bound Escape Hatches
**Policy**: All temporary exceptions must have explicit removal dates.

**Enforcement**: CI fails if any escape hatch is expired.

**Rationale**:
- SE-0337 is for incremental migration, not permanent architecture
- Automatic expiry prevents "temporary" from becoming permanent
- Forces migration completion

### 4. Structure-Aware Over Regex
**Policy**: Use SwiftSyntax AST analysis, not text pattern matching.

**Rationale**:
- Cannot be fooled by formatting tricks, whitespace, or comments
- Understands actual code structure and context
- Provides precise location data for violations

## Truth Table

| Concept | Language Truth | Policy Choice | Enforcement |
|----------|----------------|----------------|-------------|
| Static vars in actors | Never isolated | Allow ANY global actor | @GlobalActor required |
| @preconcurrency | Import-only bridge | Import-only enforcement | Declarations fail |
| Global actors | Any custom actor allowed | Custom actors permitted | Any @GlobalActor allowed |
| Strict checking | Swift 6 = complete by default | Dual validation required | Both + env var tested |
| Macro expansion | Only source visible | Analyze definitions + expansions | Post-expansion checking |
| #if branches | Context-dependent | "Any branch violation" policy | Dead code still relevant |

## Enforcement Honesty Statement

> **"Our enforcement system clearly distinguishes between Swift 6 language requirements and our architectural policy choices. Language truths are non-negotiable. Policy choices are documented architectural decisions that can be debated and changed, but are never misrepresented as language requirements."**

## Update Process

When Swift 6 language rules change:
1. Update **Language Truths** section with new requirements
2. Evaluate impact on current **Policy Choices**
3. Update enforcement tools as needed
4. Update this documentation

When architectural priorities change:
1. Update **Policy Choices** section with new decisions
2. Update enforcement tools to reflect new policies
3. Communicate changes through governance process
4. Update this documentation

## Compliance Verification

This document serves as the **source of truth** for:
- CI/CD pipeline configuration questions
- Code review disputes about enforcement rules
- Architecture decisions and their rationale
- Tooling development priorities

---

**Version**: 1.0  
**Last Updated**: $(date)  
**Next Review**: When Swift 6 language changes or major architectural decisions are made