# Native Library Lifecycle Governance

> **The canonical source of truth for how native libraries work in Anigma**
>
> This document establishes the **only approved path** for introducing, managing, and maintaining native library dependencies in the Anigma ecosystem. Any deviation from this framework risks project failure through security vulnerabilities, compliance violations, or architectural drift.

## Executive Summary

**Native libraries are not optional features - they are architectural liabilities that must be governed.** Every native dependency introduces security risks, compliance obligations, and operational complexity that can compromise the entire platform if not properly managed.

This governance framework ensures that native libraries provide value **without compromising**:
- Security posture (vulnerability management, sandboxing)
- Legal compliance (license compatibility, attribution)
- Operational stability (reproducibility, distribution)
- Court-safe evidence requirements (provenance, verification)

## The Boring Realities We Must Accept

### 1. Native Libraries Are Attack Surfaces
Every native dependency is a potential security breach:
- Memory corruption vulnerabilities (C/C++ code)
- Supply chain attacks (compromised builds)
- Runtime exploits (parser attacks, buffer overflows)
- Privilege escalation risks (system library integration)

### 2. Distribution Is Not Optional
Native libraries must be distributed through approved channels:
- System libraries must be version-pinned and reproducible
- Static libraries must be vendored with full build reproducibility
- Dynamic libraries must be sandboxed and validated
- All distribution must be auditable and verifiable

### 3. Legal Compliance Is Non-Negotiable
Every native dependency creates legal obligations:
- License compatibility with Anigma-SA-NC
- Attribution requirements for documentation
- Patent licensing considerations
- App Store distribution constraints

### 4. Operational Overhead Is Real
Native dependencies impose real operational costs:
- Vulnerability monitoring and patching
- Build system complexity and maintenance
- Testing across platforms and configurations
- Incident response and security updates

## Canonical Lifecycle Framework

### Phase 1: Intake Assessment (Contract Required)

**Every native library MUST have an intake contract before any code is written.**

#### Mandatory Contract Structure
Use `Docs/governance/contract-artifacts/NativeDeps/NATIVE.{LibraryName}.md` with:

1. **Purpose Statement**: What this library provides and why it's necessary
2. **Authority Boundary**: Who owns the native surface and Swift wrapper
3. **Distribution Strategy**: systemLibrary vs vendored vs custom build
4. **Version Pin**: Exact version with reproducibility requirements
5. **License Analysis**: Compatibility review and attribution requirements
6. **Security Posture**: Threat model and mitigations
7. **API Contract**: Wrapper requirements and error mapping
8. **Governance Hooks**: Receipt requirements and compliance checks
9. **Acceptance Tests**: Comprehensive testing requirements

#### Intake Decision Matrix
| Factor | Required | Must Pass |
|--------|----------|-----------|
| **Business Need** | Clear, documented requirement | ✅ Essential, not nice-to-have |
| **No Swift Alternative** | Confirmed no native Swift equivalent | ✅ Exhaustive alternatives checked |
| **Security Review** | Threat model completed | ✅ Acceptable risk profile |
| **License Compatibility** | Legal review completed | ✅ Compatible with Anigma-SA-NC |
| **Distribution Path** | Clear, auditable distribution | ✅ Reproducible and verifiable |
| **Maintenance Plan** | Long-term support strategy | ✅ Resources allocated |

### Phase 2: Secure Implementation

#### Authority Boundary Enforcement
```swift
// CORRECT: Clear ownership and boundaries
Native surface owner: Sources/ExternalC/Storage/SQLite
Swift wrapper owner: Sources/DatabaseCore
Allowed call sites: DatabaseCore only
Hard rule: no other target may import the native target directly
```

#### Sandboxing Requirements
- **Filesystem**: Native targets must not write outside their sandbox
- **Network**: All network access must go through governed surfaces
- **Resources**: Memory and CPU limits enforced
- **Privileges**: Minimal required privileges only

#### API Contract Requirements
- **Deterministic**: Same inputs always produce same outputs
- **Error Mapping**: Native errors map to typed Swift errors
- **Resource Management**: Clear ownership and lifecycle management
- **Actor Isolation**: Thread-safe access patterns enforced

### Phase 3: Distribution Compliance

#### Reproducibility Requirements
```bash
# Every native library must be verifiable
git clone <native-library-repo>
git checkout <exact-version-commit>
# Build process must be deterministic
./build.sh --reproducible
# Output hash must match recorded value
sha256sum lib/*.so > recorded-hashes.txt
```

#### Distribution Channels
1. **System Libraries**: Use system packages, version-pin in build
2. **Vendored Libraries**: Full source in repo, reproducible builds
3. **Custom Builds**: Managed build process with signed artifacts
4. **Binary Dependencies**: Cryptographic verification only

#### Evidence Generation
Every distribution must generate:
- Build receipts with full provenance
- Hash verification for all artifacts
- License attribution files
- Security assessment reports

### Phase 4: Operational Governance

#### Vulnerability Management
- **Monitoring**: Continuous vulnerability scanning
- **Patching**: Automated security updates
- **Validation**: Regression testing before deployment
- **Reporting**: Security incident documentation

#### Compliance Monitoring
- **License Audits**: Regular license compliance checks
- **Attribution Updates**: Automatic attribution file updates
- **Distribution Audits**: Verify distribution compliance
- **Legal Review**: Annual legal compliance assessment

#### Performance Monitoring
- **Resource Usage**: Memory, CPU, storage metrics
- **Build Impact**: Build time and artifact size tracking
- **Runtime Impact**: Performance regression detection
- **Quality Metrics**: Crash rates and error tracking

## Decision Framework: When to Accept Native Dependencies

### ✅ Acceptable Scenarios
1. **System Integration**: Essential OS integration (filesystem, security)
2. **Performance Critical**: Proven performance advantage over Swift
3. **Legacy Integration**: Required for existing system compatibility
4. **Specialized Hardware**: Hardware acceleration or device interfaces

### ❌ Unacceptable Scenarios
1. **Convenience**: Pure development convenience without critical need
2. **Rapid Prototyping**: Temporary solutions that become permanent
3. **Feature Parity**: Matching features available in Swift ecosystem
4. **Skill Gap**: Team unfamiliar with Swift equivalent

### ⚠️ Requires Exception Review
1. **Emerging Technologies**: New capabilities not yet available in Swift
2. **Research Dependencies**: Experimental or academic dependencies
3. **Ecosystem Dependencies**: Required for third-party integrations
4. **Performance Optimization**: Significant but not critical performance gains

## Implementation Path: From Current State to Compliance

### Step 1: Audit Existing Dependencies
```bash
# Find all native dependencies
find Sources/ -name "*.c" -o -name "*.cpp" -o -name "*.h"
# Check for missing contracts
ls Docs/governance/contract-artifacts/NativeDeps/
# Verify compliance
./Scripts/validate_native_contracts.sh
```

### Step 2: Create Missing Contracts
- For each existing native dependency without a contract
- Complete full intake assessment retroactively
- Document current implementation against requirements
- Create migration plan to full compliance

### Step 3: Implement Distribution Compliance
- Add build reproducibility to vendored libraries
- Implement hash verification for system libraries
- Create automated distribution verification
- Add evidence generation to build process

### Step 4: Enable Operational Monitoring
- Add vulnerability scanning to CI/CD
- Implement compliance monitoring
- Create performance monitoring dashboards
- Establish incident response procedures

## Enforcement and Governance

### CI/CD Enforcement
```yaml
# Every PR must validate native dependencies
jobs:
  native-dependency-check:
    steps:
      - name: Validate Native Library Contracts
        run: ./Scripts/validate_native_contracts.sh
      - name: Verify Distribution Compliance
        run: ./Scripts/verify_distribution_compliance.sh
      - name: Check Vulnerability Status
        run: ./Scripts/check_vulnerabilities.sh
      - name: Generate Build Evidence
        run: ./Scripts/generate_build_evidence.sh
```

### Governance Hooks
- **NativeDepUpdate**: Receipt for any native library update
- **VulnerabilityDetected**: Alert for new security issues
- **ComplianceViolation**: Detection of compliance issues
- **DistributionFailure**: Build or distribution problems

### Review Process
1. **Monthly Security Review**: Vulnerability assessment
2. **Quarterly Compliance Review**: License and distribution compliance
3. **Annual Architecture Review**: Dependency necessity assessment
4. **Continuous Monitoring**: Automated compliance and security checks

## Resources and References

### Essential Reading
1. **[Dependency Boundary Policy](Dependency-Boundary-Policy.md)** - Core governance rules
2. **[Security Posture Requirements](../security/overview.md)** - Security framework
3. **[License Compliance Guide](../legal/)** - Legal requirements
4. **[Implementation Rules](../ImplementationRules.md)** - Build requirements

### Contract Templates
- **Native Library Intake Contract**: Use existing `NATIVE.SQLite.md` as template
- **Distribution Compliance**: Reference `SURFACE.MakerEngineEnhancements.md` for distribution patterns
- **Security Assessment**: Follow security posture sections in existing contracts

### Tools and Scripts
- **Contract Validation**: Automated validation of contract completeness
- **Distribution Verification**: Build reproducibility checking
- **Vulnerability Scanning**: Continuous security monitoring
- **Evidence Generation**: Automated provenance tracking

## Conclusion: Governance as Product

**The dependency lifecycle governance framework is not bureaucracy - it's product.** It ensures that native libraries deliver value while protecting the platform from the inevitable risks they introduce.

Every native dependency choice is a trade-off between capability and risk. This framework ensures we make those trade-offs consciously, document them thoroughly, and manage them rigorously throughout the library's lifecycle.

**Follow this framework or risk project failure.** There is no middle ground.

---

*This document is the single source of truth for native library governance in Anigma. All other documentation must reference this framework as the authoritative guide.*

## Cross-Reference Index

### Documents That Must Reference This Guide
1. **[README.md](../../README.md)** - Main project documentation
2. **[Overview.md](../Overview.md)** - Architecture overview
3. **[ImplementationRules.md](../ImplementationRules.md)** - Development guidelines
4. **[Roadmap.md](../Roadmap.md)** - Development roadmap
5. **[Dependency-Boundary-Policy.md](Dependency-Boundary-Policy.md)** - Core policy
6. All NATIVE.* contracts in `contract-artifacts/NativeDeps/`
7. All SURFACE.* contracts in `contract-artifacts/`

### Integration Points
- **Contract Artifacts**: All native library contracts must comply with this framework
- **Surface Contracts**: Must reference sandboxing and resource limits from this guide
- **Implementation Guides**: Must follow distribution and security requirements
- **Roadmap Documents**: Must prioritize compliance over features

### Decision Flow
1. **Need Identified** → Check this framework first
2. **Contract Required** → Use template from this framework
3. **Implementation** → Follow security and distribution requirements
4. **Distribution** → Follow compliance verification process
5. **Operations** → Follow monitoring and maintenance procedures

*Any document that conflicts with this framework is considered outdated and must be updated.*
