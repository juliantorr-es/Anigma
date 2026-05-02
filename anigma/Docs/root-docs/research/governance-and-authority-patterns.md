> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


---
title: "Authorization and Policy Enforcement Patterns for Harmonia V3"
description: "Comprehensive research on governance, authorization models, and policy decision frameworks for runtime action governance"
created: 2025-04-16
updated: 2025-04-16
status: research
type: research-document
audience: architecture, security, design
---

# Authorization and Policy Enforcement Patterns for Harmonia V3 Runtime

## Executive Summary

This research document provides a comprehensive analysis of modern authorization patterns, policy decision frameworks, and governance approaches suitable for Harmonia V3's runtime action governance. Based on analysis of industry-leading systems (AWS IAM, Google Cloud IAM, Kubernetes RBAC), policy engines (OPA/Rego, XACML), and emerging patterns (relationship-based access control), we recommend a **hybrid approach combining hierarchical RBAC as a foundation with ABAC capabilities for fine-grained policy enforcement** using an embedded policy engine.

### Recommended Approach at a Glance

```
┌─────────────────────────────────────────────────────────────┐
│           Harmonia V3 Authorization Architecture            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Layer 1: Authentication (Identity verification)             │
│           ↓                                                   │
│  Layer 2: Hierarchical RBAC (Base permissions model)         │
│           ↓                                                   │
│  Layer 3: Attribute-Based Policies (Dynamic conditions)      │
│           ↓                                                   │
│  Layer 4: Resource-Level Access (Fine-grained control)       │
│           ↓                                                   │
│  Layer 5: Audit & Enforcement (Logging & enforcement)        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Key Recommendation Highlights

| Aspect | Recommendation | Rationale |
|--------|-----------------|-----------|
| **Primary Model** | Hierarchical RBAC + ABAC (hybrid) | Simplicity for common cases, fine-grained when needed |
| **Policy Engine** | Embedded policy evaluator (Rego-inspired) | Lower latency, no external service dependency |
| **Policy Language** | Declarative JSON-based DSL | Easier than Rego for operators, proven by OPA patterns |
| **Decision Point** | Centralized PDP (Policy Decision Point) | Consistent enforcement, auditable decisions |
| **Scope Hierarchy** | Organization → Workspace → Resource | Multi-tenancy support from the ground up |
| **Audit Model** | Strong consistency with event logging | Security-critical: all decisions logged with context |

---

## Section 1: Authorization Pattern Research

### 1.1 Role-Based Access Control (RBAC)

#### What is RBAC?

RBAC is an access control approach that restricts system access based on **predefined roles** assigned to users. Permissions are grouped into roles (e.g., "Admin", "Editor", "Viewer"), and users inherit permissions through role assignment.

**Core Components:**
- **Roles**: Named sets of permissions (e.g., `workspace-admin`, `resource-editor`)
- **Permissions**: Approved operations (e.g., `read`, `write`, `delete`, `execute`)
- **Subjects**: Users, service accounts, or groups
- **Resources**: Things being protected (documents, environments, tools)
- **Session**: Active context combining subject + selected roles

#### RBAC Strengths

| Strength | Explanation |
|----------|-------------|
| **Simplicity** | Familiar model; easy to understand and communicate |
| **Scalability** | Works well for 100-1000 users without explosion |
| **Manageability** | Reduce individual permission management to role assignment |
| **Auditability** | Clear role hierarchy makes audits straightforward |
| **Well-tested** | NIST/INCITS standardized (RFC 4876) |
| **Performance** | Fast decision-making with simple lookups |

#### RBAC Weaknesses

| Weakness | Impact | Mitigation |
|----------|--------|-----------|
| **Role Explosion** | In large orgs, roles proliferate (100+ roles for 50 users) | Define clear role naming conventions; use hierarchy |
| **Limited Granularity** | Cannot encode complex conditions (time, location, data sensitivity) | Combine with ABAC for dynamic policies |
| **Static Permissions** | Hard to implement contextual access (temporary elevation) | Use role hierarchies + session management |
| **Coarse-Grained** | Cannot restrict access to specific resources (e.g., document #5) | Layer in relationship-based or resource policies |

#### RBAC in Production Systems

**AWS IAM (Identity and Access Management)**
- AWS uses identity-based policies attached to IAM entities
- Combines RBAC concepts with resource-based policies
- Standard: "Allow" principals specific actions on resources
- Example: `arn:aws:iam::ACCOUNT:role/AWSServiceRoleForLambda`

**Kubernetes RBAC**
- Four core objects: `Role`, `ClusterRole`, `RoleBinding`, `ClusterRoleBinding`
- Namespace-scoped roles for fine-grained control
- ClusterRoles for cluster-wide permissions
- Simple rule structure: `apiGroups`, `resources`, `verbs`

#### RBAC for Harmonia V3

**Suitability**: ⭐⭐⭐⭐☆ (Very suitable as foundation)

**Proposed Roles:**
```
# Core operation roles
- workspace_owner: Full control of workspace, including user management
- workspace_editor: Can create/edit/execute tools, manage configurations
- workspace_viewer: Read-only access to resources
- tool_executor: Can execute specific tools
- tool_developer: Can create/modify tools

# Resource-specific roles
- env_admin: Full control of environment
- env_operator: Can deploy and manage, not create/delete
- env_viewer: Read-only access
```

---

### 1.2 Attribute-Based Access Control (ABAC)

#### What is ABAC?

ABAC extends RBAC by making authorization decisions based on **attributes** describing the subject (user), resource, action, and environment. Policies are expressions over these attributes.

**Core Components:**
- **Subject Attributes**: `role`, `department`, `security_clearance`, `has_mfa`
- **Resource Attributes**: `data_classification`, `owner`, `environment`, `created_date`
- **Action Attributes**: Operation being performed, method (API vs. UI)
- **Environment Attributes**: `current_time`, `source_ip`, `request_location`
- **Policies**: Boolean expressions combining these attributes

#### ABAC Example

```
Policy: "Only employees in Engineering dept with 2FA can deploy to production"

Condition: 
  (subject.role == "developer" AND 
   subject.department == "engineering" AND 
   subject.has_mfa == true AND 
   resource.environment == "production" AND 
   action == "deploy")
  → permit
```

#### ABAC Strengths

| Strength | Explanation |
|----------|-------------|
| **Fine-Grained** | Control down to individual resource attributes |
| **Dynamic** | Policies react to real-time attribute changes |
| **Flexible** | Easy to implement complex business logic |
| **Context-Aware** | Can enforce time-of-day, geolocation, threat level |
| **Future-Proof** | Add new attributes without changing policy structure |

#### ABAC Weaknesses

| Weakness | Impact | Mitigation |
|----------|--------|-----------|
| **Complexity** | Steep learning curve; hard to design policies | Use templates and visual policy builders |
| **Performance Overhead** | Attribute evaluation can be slow at scale | Cache policy decisions; use lazy evaluation |
| **Difficult to Audit** | Complex policies are hard to reason about | Maintain policy documentation; use policy versioning |
| **Attribute Explosion** | System becomes unwieldy with many attributes | Keep attribute set disciplined and bounded |
| **Debugging** | Hard to understand why a decision was made | Implement detailed decision logging with reasoning |

#### ABAC in Production Systems

**AWS Identity-Based Policies with Conditions**
- Policy conditions enable attribute-based decisions
- Example: Grant S3 access only from specific IP ranges
```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::bucket/*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["192.168.1.0/24"]
    },
    "StringEquals": {
      "aws:username": "alice"
    }
  }
}
```

**Google Cloud IAM with Custom Attributes**
- Resource attributes (labels) drive access decisions
- Context-aware policies based on request metadata
- Attribute Hierarchy (Organization → Folder → Project)

#### ABAC for Harmonia V3

**Suitability**: ⭐⭐⭐⭐⭐ (Excellent for runtime governance)

**Proposed Attributes:**
```
Subject Attributes:
  - role (viewer, editor, admin)
  - workspace (assigned workspaces)
  - team (project team assignment)
  - has_mfa (MFA enabled)
  - trusted_ip (source IP whitelist)
  - api_key_rotation_age (days since rotation)

Resource Attributes:
  - type (tool, environment, workflow, secret)
  - environment (dev, staging, prod)
  - sensitivity (public, internal, restricted, secret)
  - owner (user/team ID)
  - requires_approval (boolean)
  - rate_limit (requests/sec)

Environment Attributes:
  - current_time (for time-based access)
  - request_source (api, ui, automation)
  - threat_level (normal, elevated, critical)
```

---

### 1.3 Policy-Based Access Control (PBAC)

#### What is PBAC?

PBAC is a broader term encompassing access control systems where **policies are first-class, versionable, and auditable artifacts**. Policies can implement RBAC, ABAC, or custom logic.

**Key Characteristics:**
- Policies are code/configuration artifacts (versioned, reviewed)
- Policy evaluation is deterministic and reproducible
- Strong separation between policy definition and enforcement
- Audit trail of policy changes and decisions

#### PBAC Strengths

| Strength | Explanation |
|----------|-------------|
| **Auditability** | Policy changes are tracked; decisions are reproducible |
| **Versioning** | Roll back broken policies without affecting code |
| **Flexibility** | Implement any access control logic |
| **Compliance** | Meet regulatory requirements for policy documentation |
| **Separation of Concerns** | Business policies separate from enforcement code |

#### PBAC Weaknesses

| Weakness | Impact |
|----------|--------|
| **Operational Overhead** | Requires policy management infrastructure |
| **Learning Curve** | Operators need to understand policy language |
| **Debugging Complexity** | Troubleshooting policy evaluation can be hard |

#### PBAC in Production Systems

**AWS Service Control Policies (SCPs)**
- Organization-wide policy enforcement
- Hierarchical policy evaluation (org → OU → account)
- Deny-by-default model

**Kubernetes NetworkPolicies**
- Network policies as YAML artifacts
- Versioned in configuration management
- Applied to pods/namespaces

#### PBAC for Harmonia V3

**Suitability**: ⭐⭐⭐⭐⭐ (Essential for governance)

---

### 1.4 Relationship-Based Access Control (ReBAC)

#### What is ReBAC?

ReBAC (popularized by Google's Zanzibar) determines access based on **explicit relationships** between subjects and resources. Instead of roles or attributes, the system tracks "user U has relation R to resource X".

**Example Relationships:**
```
- alice is_member_of engineering_team
- engineering_team has_access_to production_env
- bob is_owner_of workflow_123
- workflow_123 belongs_to workspace_456
```

#### ReBAC Strengths

| Strength | Explanation |
|----------|-------------|
| **Fine-Grained** | Precise relationship-based control |
| **Scalable** | Efficient graph-based lookup |
| **Flexible** | Supports complex hierarchies |
| **Queryable** | "Who can access X?" becomes a graph query |

#### ReBAC Weaknesses

| Weakness | Impact |
|----------|--------|
| **Operational Complexity** | Relationship graph must be maintained correctly |
| **Performance Sensitive** | Graph traversal can be slow without optimization |
| **Not Attribute-Based** | Hard to encode dynamic policies (time, conditions) |

#### ReBAC in Production Systems

**Google Zanzibar (Internal)**
- Powers Google Cloud IAM
- Relationship-based with strong consistency guarantees
- Sub-millisecond authorization checks

**Auth0 Authorization Extension**
- Relationship-based role hierarchy
- Used by enterprises for complex org structures

**SpiceDB (Open Source)**
- Inspired by Zanzibar
- Apache 2.0 licensed; self-hosted
- Supports relationship-based access control with "caveats" (lightweight policies)

#### ReBAC for Harmonia V3

**Suitability**: ⭐⭐⭐☆☆ (Good for hierarchical relationships, not primary)

---

### 1.5 Capability-Based Security

#### What is Capability-Based Security?

Capability-based security grants access through unforgeable **capabilities** (tokens) that represent a permission to perform an action on a resource. The capability itself proves authorization.

**Example:**
```
Token: eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicmVzb3VyY2UiOiJkb2NBQkMiLCJhY3Rpb24iOiJyZWFkIn0
```

The token encodes: "Bearer of this token can read document ABC".

#### Capability-Based Security Strengths

| Strength | Explanation |
|----------|-------------|
| **Decentralized** | No central authority needed; capability is proof |
| **Delegation** | Easy to delegate by sharing tokens |
| **Performance** | Fast verification (cryptographic signature check) |
| **Zero-Trust** | Works in untrusted networks |

#### Capability-Based Security Weaknesses

| Weakness | Impact |
|----------|--------|
| **Token Management** | Hard to revoke capabilities in real-time |
| **Granularity** | Each capability represents one permission; many tokens needed |
| **Revocation** | Requires central revocation server (defeats decentralization) |
| **Auditability** | Hard to audit who used a capability |

#### Capability-Based Security in Production Systems

**JWTs (JSON Web Tokens)**
- Self-contained capabilities with cryptographic signature
- No per-request server lookup needed
- Used in OAuth 2.0, OpenID Connect

**API Keys with Scopes**
- Each API key is a capability
- Scopes define permitted operations
- Used by AWS, GitHub, many APIs

#### Capability-Based Security for Harmonia V3

**Suitability**: ⭐⭐⭐☆☆ (Good for tool invocations; not sole mechanism)

**Use Case**: Tool execution tokens
```
Tool execution capability:
{
  "subject": "alice@company.com",
  "resource": "tool_deploy",
  "action": "execute",
  "workspace_id": "ws-123",
  "expires_at": "2025-04-17T12:00:00Z",
  "signature": "..."
}
```

---

## Section 2: Policy Decision Frameworks

### 2.1 Open Policy Agent (OPA) & Rego

#### Overview

**Open Policy Agent (OPA)** is a Cloud Native Computing Foundation (CNCF) graduated project providing a **unified policy engine** for enforcement across the stack. OPA decouples policy decision-making (in a central PDP) from policy enforcement (distributed PEPs).

**Rego** is OPA's declarative policy language, purpose-built for expressing policies over complex hierarchical data.

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Policy Enforcement Point (PEP)             │
│  (Interceptor in app, API gateway, etc.)               │
└─────────────────────┬───────────────────────────────────┘
                      │
                      │ JSON Query
                      ↓
┌─────────────────────────────────────────────────────────┐
│              Policy Decision Point (PDP)                │
│  ┌─────────────────────────────────────────────────────┐│
│  │  OPA Engine + Rego Policies                         ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  Accesses:                                              │
│  - Policies (Rego files)                               │
│  - External Data (via Policy Information Point)        │
└─────────────────────────────────────────────────────────┘
```

#### Rego Language Basics

**Query Structure:**
```rego
package healthcare.authz

# Define allowed actions
allow if {
  # Subject has required role
  input.user.role == "doctor"
  
  # And resource is accessible in time window
  current_time >= input.resource.access_start
  current_time <= input.resource.access_end
  
  # And request comes from trusted network
  input.request.source_ip in trust_networks
}

# Deny unauthorized access
deny if {
  input.action == "delete"
  input.user.role != "admin"
}
```

**Key Rego Features:**
- **Declarative**: Specify what should happen, not how
- **Pattern Matching**: Powerful data querying
- **Built-in Functions**: String ops, math, aggregation, crypto
- **Multiple Rules**: OR logic across rules; AND logic within
- **Iteration**: Implicit iteration over arrays/objects

#### OPA Strengths

| Strength | Explanation |
|----------|-------------|
| **Unified Engine** | Single policy system for entire stack |
| **Flexible** | Expresses RBAC, ABAC, PBAC, custom logic |
| **Cloud Native** | CNCF project; used by Kubernetes, Docker |
| **Performance** | Fast evaluation; caching and indexing support |
| **Mature** | Production-proven by large enterprises |
| **Tooling** | IDE support, testing frameworks, CLI |

#### OPA Weaknesses

| Weakness | Impact | Mitigation |
|----------|--------|-----------|
| **Learning Curve** | Rego syntax unfamiliar to many developers | Use templates; provide examples |
| **Policy Complexity** | Policies can become hard to reason about | Enforce code review; unit test policies |
| **External Data** | Must fetch data from Policy Information Point (PIP) | Cache; use lazy evaluation |
| **Latency** | Each check calls OPA; adds 10-100ms | Use local evaluation; cache results |

#### OPA Use Cases in Production

**Kubernetes Policy Enforcement**
- Gatekeeper: Validates pod specs before admission
- Controls image registries, resource limits, labels

**API Gateway Authorization**
- Envoy, Kong integrate OPA
- Centralized auth for API calls

**Infrastructure as Code Scanning**
- Terraform, Dockerfile policy validation
- Before-deployment compliance checks

#### OPA for Harmonia V3

**Suitability**: ⭐⭐⭐⭐☆ (Excellent for policy evaluation)

**Pros for Harmonia:**
- Can express complex runtime policies
- Separates policy code from enforcement logic
- Mature; CNCF pedigree
- Good tooling and community support

**Cons for Harmonia:**
- Introduces external dependency; adds latency
- Rego learning curve for operators
- Overkill for simple RBAC checks

**Recommendation**: Use OPA patterns (policy-as-code, PDP/PEP separation) but implement embedded evaluator in Go for low-latency decisions.

---

### 2.2 XACML (eXtensible Access Control Markup Language)

#### Overview

**XACML** is an OASIS standard for attribute-based access control. It provides an XML-based policy language and architecture for expressing access control decisions.

#### XACML Architecture

```
┌─────────────────────────────────────────┐
│  Policy Administration Point (PAP)      │
│  (Manages policies)                     │
└────────────────────┬────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────┐
│  Policy Retrieval Point (PRP)           │
│  (Stores policies - filesystem/DB)      │
└────────────────────┬────────────────────┘
                     │
     ┌───────────────┼───────────────┐
     ↓               ↓               ↓
  ┌─────────────────────────────────┐
  │  Policy Decision Point (PDP)    │
  │  - Evaluates policies           │
  │  - Queries Policy Info Point    │
  └────────────┬────────────────────┘
               ↓
┌──────────────────────────────────┐
│  Policy Information Point (PIP)  │
│  (External data: LDAP, DB, etc.) │
└──────────────────────────────────┘
               ↑
  ┌───────────┴──────────────┐
  ↓                          ↓
┌──────────────────────┐  ┌──────────────────┐
│ Policy Enforcement   │  │ Access Request   │
│ Point (PEP)          │  │ from Application │
└──────────────────────┘  └──────────────────┘
```

#### XACML Policy Example

```xml
<Policy PolicyId="urn:example:policy:1" RuleCombiningAlgId="...:deny-unless-permit">
  <Target>
    <AnyOf>
      <AllOf>
        <Match MatchId="...:string-equal">
          <AttributeValue DataType="...:string">edit</AttributeValue>
          <AttributeDesignator AttributeId="urn:oasis:names:tc:xacml:2.0:action:action-id"/>
        </Match>
      </AllOf>
    </AnyOf>
  </Target>
  
  <Rule RuleId="urn:example:rule:1" Effect="Permit">
    <Target>
      <AnyOf>
        <AllOf>
          <Match MatchId="...:string-equal">
            <AttributeValue DataType="...:string">editor</AttributeValue>
            <AttributeDesignator AttributeId="urn:example:subject:role"/>
          </Match>
        </AllOf>
      </AnyOf>
    </Target>
    <Condition>
      <Apply FunctionId="...:string-equal">
        <Apply FunctionId="...:string-one-and-only">
          <AttributeDesignator AttributeId="urn:example:resource:owner"/>
        </Apply>
        <AttributeValue DataType="...:string">alice</AttributeValue>
      </Apply>
    </Condition>
  </Rule>
</Policy>
```

#### XACML Strengths

| Strength | Explanation |
|----------|-------------|
| **Standardized** | OASIS standard; interoperability |
| **Comprehensive** | Handles complex policy requirements |
| **Mature** | 20+ years of refinement; v3.0 (2013) and v4.0 coming |
| **Clear Architecture** | PDP/PEP separation; audit trail |
| **JSON Support** | XACML 4.0 includes JACAL (JSON XACML) |

#### XACML Weaknesses

| Weakness | Impact | Mitigation |
|----------|--------|-----------|
| **Verbose** | XML/JSON can be wordy | Use policy generation tools |
| **Learning Curve** | Complex concepts (combining algorithms, etc.) | Provide templates |
| **Performance** | XML parsing and evaluation slower than Rego | Use compiled format |
| **Overkill for Simple Cases** | Introduces complexity for basic RBAC | Use for complex policies only |

#### XACML for Harmonia V3

**Suitability**: ⭐⭐⭐☆☆ (Good for compliance; complex setup)

**Recommendation**: Reference XACML architecture (PDP/PEP) but use simpler JSON-based DSL rather than full XACML.

---

### 2.3 Custom DSLs and Go-Based Evaluators

#### Motivation

For Harmonia V3, a **custom declarative policy language optimized for Harmonia's domain** may be better than generic solutions.

#### Example Custom DSL

```yaml
# governance/policies/default.yaml

policy:
  version: "1.0"
  description: "Default authorization policies for Harmonia"

rules:
  - name: "workspace-owner-full-access"
    description: "Workspace owners can perform any action"
    condition:
      - subject.role == "workspace_owner"
    effect: "allow"

  - name: "tool-executor-can-run-tools"
    description: "Tool executors can execute assigned tools"
    condition:
      - subject.role == "tool_executor"
      - subject.assigned_tools contains resource.tool_id
      - environment.threat_level != "critical"
    effect: "allow"
    obligations:
      - log_action: true
      - require_mfa: true
        if: resource.sensitivity == "secret"

  - name: "production-requires-approval"
    description: "Production deployments require approval"
    condition:
      - resource.environment == "production"
      - action == "deploy"
    effect: "deny"
    unless:
      - subject.has_approval == true
      - approval.expires_at > now()

  - name: "ip-restricted-access"
    description: "Restrict access by source IP"
    condition:
      - resource.ip_whitelist is not empty
      - request.source_ip not in resource.ip_whitelist
    effect: "deny"
    exceptions:
      - subject.role == "admin"
```

#### Custom DSL Strengths

| Strength | Explanation |
|----------|-------------|
| **Optimized** | DSL tailored to Harmonia domain |
| **Simple** | No learning curve for operators |
| **Performant** | Direct evaluation; no interpretation overhead |
| **Lean** | Smaller attack surface than generic engine |

#### Custom DSL Weaknesses

| Weakness | Impact | Mitigation |
|----------|--------|-----------|
| **Maintenance** | Must maintain evaluator | Use generated code from DSL |
| **Less Flexible** | Can't easily express arbitrary logic | Design DSL to be extensible |
| **Limited Community** | No pre-built tools/IDE support | Build tooling; document well |

---

## Section 3: Fine-Grained Access Control

### 3.1 Resource-Level Access Policies

#### Concept

**Resource-level access** restricts access to individual resources (not just resource types). Instead of "user can read documents", it's "user can read document #5".

#### Implementation Patterns

**Pattern 1: Access Control Lists (ACLs)**
```
Document #5 ACL:
  - alice: read, write
  - bob: read
  - team-engineering: read
```

**Pattern 2: Resource-Based Policies**
```json
{
  "resource_id": "workflow_abc123",
  "owner": "alice@company.com",
  "allow": [
    {
      "principal": "bob@company.com",
      "actions": ["read", "execute"]
    }
  ],
  "deny": [
    {
      "principal": "external-contractor@vendor.com",
      "actions": ["delete"]
    }
  ]
}
```

**Pattern 3: ReBAC with Relationships**
```
Alice → "owns" → Workflow_ABC123
Bob → "is_member_of" → Team_Engineering
Team_Engineering → "has_access_to" → Workflow_ABC123
```

#### Implementation Complexity for Harmonia V3

**Low Complexity (Recommended):**
- ACLs stored in resource metadata
- Simple lookup at access time
- Suitable for workspace, tool, and workflow resources

**Example:** Harmonia Tool Access
```python
class Tool:
    def __init__(self, tool_id: str):
        self.id = tool_id
        self.owner = "alice@company.com"
        self.acl = [
            {"principal": "bob@company.com", "actions": ["execute"]},
            {"principal": "workspace_123", "actions": ["read"]},
        ]
    
    def check_access(self, subject: str, action: str) -> bool:
        for acl_entry in self.acl:
            if acl_entry["principal"] == subject and action in acl_entry["actions"]:
                return True
        return False
```

---

### 3.2 Hierarchical Scoping

#### Concept

**Hierarchical scoping** defines a containment hierarchy where permissions cascade down. A typical hierarchy for Harmonia V3:

```
Organization (top level)
├── Workspace 1
│   ├── Tool A
│   ├── Tool B
│   ├── Workflow W1
│   └── Environment E1 (staging)
│       ├── Deployed Tool A
│       └── Logs
├── Workspace 2
│   └── Environment E2 (production)
└── Team (cross-workspace)
    ├── Members
    └── Permissions (inherited by all member workspaces)
```

#### Hierarchy Rules

1. **Permissions inherit downward**: If user has access at workspace level, they inherit access to contained resources (unless explicitly denied)
2. **Explicit overrides implicit**: Resource-level permissions override workspace-level permissions
3. **Deny takes precedence**: Explicit deny at any level prevents access

#### Implementation

```go
type Scope string

const (
  ScopeOrganization Scope = "organization"
  ScopeWorkspace    Scope = "workspace"
  ScopeResource     Scope = "resource"
)

type Permission struct {
  Scope      Scope
  ScopeID    string       // organization_id, workspace_id, or resource_id
  Principal  string       // user@company.com
  Role       Role         // viewer, editor, admin
  ExpiresAt  time.Time
}

func ResolvePermissions(subject string, resource Resource) (Role, error) {
  // 1. Check resource-level permissions
  if perm := checkScope(subject, ScopeResource, resource.ID); perm != nil {
    return perm.Role, nil
  }
  
  // 2. Check workspace-level permissions
  if perm := checkScope(subject, ScopeWorkspace, resource.WorkspaceID); perm != nil {
    return perm.Role, nil
  }
  
  // 3. Check organization-level permissions
  if perm := checkScope(subject, ScopeOrganization, resource.OrgID); perm != nil {
    return perm.Role, nil
  }
  
  return RoleNone, ErrAccessDenied
}
```

---

### 3.3 Audit Logging Requirements

#### What to Log

**Every authorization decision must be logged with complete context:**

```json
{
  "timestamp": "2025-04-16T14:32:15Z",
  "event_type": "authorization_decision",
  "decision": "permit",
  "subject": {
    "id": "user_alice@company.com",
    "roles": ["workspace_editor", "tool_executor"],
    "source_ip": "192.168.1.100"
  },
  "action": "execute",
  "resource": {
    "type": "tool",
    "id": "tool_deploy_v2",
    "workspace_id": "ws_abc123",
    "sensitivity": "high"
  },
  "context": {
    "request_id": "req_xyz789",
    "user_agent": "harmonia-cli/1.2.3",
    "mfa_verified": true
  },
  "reasoning": {
    "matched_rules": ["rule_executor_can_run_tools"],
    "decision_time_ms": 2.5
  }
}
```

#### Audit Log Access

- **Who can see logs?** Only organization admins and security team
- **Log retention**: Comply with regulatory requirements (6+ years for regulated industries)
- **Immutability**: Logs should be append-only; never modified after creation
- **Search**: Support searching by subject, resource, action, decision

#### Implementation

```go
type AuditLogger interface {
  LogAuthorizationDecision(ctx context.Context, event AuthEvent) error
  QueryLogs(filter AuditFilter) ([]AuthEvent, error)
}

type AuthEvent struct {
  Timestamp    time.Time
  EventType    string                 // "authorization_decision", "policy_update", "permission_grant"
  Decision     string                 // "permit", "deny"
  Subject      string
  Action       string
  Resource     string
  Context      map[string]interface{}
  Reasoning    map[string]interface{} // Explain why decision was made
}
```

---

### 3.4 Real-Time vs. Eventual Consistency

#### Challenge

In distributed systems, updates to permissions may not be immediately visible everywhere. Trade-offs:

| Consistency | Latency | Cost | Suitable For |
|------------|---------|------|--------------|
| **Strong** | High (100ms+) | High (write locks, consensus) | Security-critical decisions |
| **Eventual** | Low (1-10ms) | Low (caching, async updates) | Non-critical reads |

#### Recommendation for Harmonia V3

**Use strong consistency for authorization decisions**, with optional eventual consistency for non-critical operations:

```go
// Security-critical: Strong consistency (default)
func (authz *Authorizer) CheckAccess(ctx context.Context, 
  subject, action, resource string) (bool, error) {
  
  // Always query current state from primary database
  perm := db.QueryPermission(subject, resource)
  return perm.Can(action), nil
}

// Non-critical: Eventual consistency via cache
func (authz *Authorizer) CachedCheckAccess(ctx context.Context, 
  subject, action, resource string) (bool, error) {
  
  // Check cache first (TTL: 30 seconds)
  if cached := authz.cache.Get(cacheKey(subject, resource)); cached != nil {
    return cached.Can(action), nil
  }
  
  // Cache miss; query database
  perm := db.QueryPermission(subject, resource)
  authz.cache.Set(cacheKey(subject, resource), perm, 30*time.Second)
  return perm.Can(action), nil
}
```

---

## Section 4: Runtime Action Governance

### 4.1 Tool Execution Policies

#### Challenge

**Harmonia tools can execute arbitrary commands.** Authorization must prevent:
- Unauthorized tool execution (only authorized users can run specific tools)
- Privilege escalation (tool cannot exceed executor's permissions)
- Resource exhaustion (tool cannot consume unlimited CPU/memory)
- Side-channel attacks (tool cannot access other users' data)

#### Policy Framework

```go
type ToolExecutionPolicy struct {
  ToolID              string
  AllowedRoles        []Role           // Only these roles can execute
  AllowedSubjects     []string         // Specific users allowed
  AllowedWorkspaces   []string         // Allowed deployment contexts
  RequireApproval     bool             // Human approval required?
  RequireMFA          bool             // MFA required for execution?
  RateLimitPerHour    int              // Max executions per hour
  ResourceLimits      ResourceLimits   // CPU, memory, timeout
  RequiredLabels      map[string]string // Tags the tool must have
  AuditLevel          string           // "none", "basic", "detailed"
}

type ResourceLimits struct {
  CPULimit             string          // "1000m" = 1 CPU
  MemoryLimit          string          // "512Mi" = 512MB
  TimeoutSeconds       int
  MaxOpenFiles         int
  AllowedNetworkPorts  []int           // e.g., [443, 80] for HTTPS/HTTP only
}
```

#### Implementation

```go
func (authz *Authorizer) CheckToolExecution(ctx context.Context,
  subject string, tool *Tool, workspace string) error {
  
  policy := tool.ExecutionPolicy
  
  // 1. Check role
  subjectRole, _ := authz.GetRole(subject, workspace)
  if !contains(policy.AllowedRoles, subjectRole) {
    return fmt.Errorf("role  not authorized", subjectRole)
  }
  
  // 2. Check specific subject allowlist
  if len(policy.AllowedSubjects) > 0 {
    if !contains(policy.AllowedSubjects, subject) {
      return fmt.Errorf("subject  not authorized", subject)
    }
  }
  
  // 3. Check workspace
  if !contains(policy.AllowedWorkspaces, workspace) {
    return fmt.Errorf("workspace  not authorized", workspace)
  }
  
  // 4. Check rate limit
  count, _ := authz.CountRecentExecutions(subject, tool.ID, time.Hour)
  if count >= policy.RateLimitPerHour {
    return fmt.Errorf("rate limit exceeded")
  }
  
  // 5. Check approval requirement
  if policy.RequireApproval {
    approval := authz.GetApproval(subject, tool.ID)
    if approval == nil || approval.ExpiresAt.Before(time.Now()) {
      return fmt.Errorf("approval required")
    }
  }
  
  // 6. Check MFA
  if policy.RequireMFA {
    if !authz.IsMFAVerified(subject) {
      return fmt.Errorf("MFA required")
    }
  }
  
  return nil
}
```

---

### 4.2 API Call Authorization

#### Gateway Pattern

```
┌──────────────────────────────────────┐
│         Harmonia API Request         │
│  (GET /tools/123, POST /workflows)   │
└────────────────┬─────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────┐
│  Authorization Gateway               │
│  - Extract credentials               │
│  - Validate signature                │
│  - Query Policy Decision Point       │
│  - Log decision                      │
└────────────────┬─────────────────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
     ALLOW           DENY (403 Forbidden)
        │
        ↓
┌──────────────────────────────────────┐
│    Route to Handler                  │
│    (GET /tools/123 → GetToolHandler) │
└──────────────────────────────────────┘
```

#### Implementation

```go
func (router *Router) authorizationMiddleware(w http.ResponseWriter, 
  r *http.Request, next http.Handler) {
  
  // 1. Extract subject from JWT/credentials
  subject, err := extractSubject(r)
  if err != nil {
    http.Error(w, "Unauthorized", http.StatusUnauthorized)
    return
  }
  
  // 2. Map HTTP method + path to action + resource
  action, resource := mapRequestToAction(r.Method, r.URL.Path)
  
  // 3. Query authorization
  permitted, err := authz.CheckAccess(r.Context(), subject, action, resource)
  if err != nil || !permitted {
    // Log denied access
    auditLog.LogDenied(subject, action, resource, err)
    http.Error(w, "Forbidden", http.StatusForbidden)
    return
  }
  
  // 4. Log allowed access
  auditLog.LogPermitted(subject, action, resource)
  
  // 5. Call handler
  next.ServeHTTP(w, r)
}
```

---

### 4.3 Resource Quota Enforcement

#### Challenge

A user or workspace should have limits on total resource usage:
- **Concurrent tool executions**: Max N tools running simultaneously
- **Storage quota**: Max M GB of tool outputs/logs
- **API call rate**: Max K calls per minute
- **Tool executions**: Max X tools per hour

#### Implementation

```go
type ResourceQuota struct {
  WorkspaceID               string
  ConcurrentExecutionLimit  int       // Max N tools running at once
  StorageQuotaMB            int       // Max storage in MB
  APICallsPerMinute         int       // Rate limit
  ExecutionsPerHour         int       // Max tool runs per hour
  MonthlyComputeCost        float64   // Max compute cost per month
  ResetDay                  int       // Day of month quota resets (1-28)
}

func (enforcer *QuotaEnforcer) CheckQuota(ctx context.Context, 
  workspaceID string, resource ResourceType) error {
  
  quota := enforcer.GetQuota(workspaceID)
  
  switch resource {
  case ResourceExecution:
    running := enforcer.CountRunning(workspaceID)
    if running >= quota.ConcurrentExecutionLimit {
      return ErrQuotaExceeded("concurrent executions")
    }
    
  case ResourceStorage:
    used := enforcer.GetStorageUsed(workspaceID)
    if used >= quota.StorageQuotaMB {
      return ErrQuotaExceeded("storage")
    }
    
  case ResourceAPICall:
    calls := enforcer.CountAPICalls(workspaceID, time.Minute)
    if calls >= quota.APICallsPerMinute {
      return ErrQuotaExceeded("API rate limit")
    }
  }
  
  return nil
}
```

---

### 4.4 Rate Limiting Patterns

#### Leaky Bucket Algorithm (Recommended)

```go
type RateLimiter struct {
  capacity    int       // Max tokens in bucket
  refillRate  int       // Tokens added per second
  tokens      int
  lastRefill  time.Time
  lock        sync.Mutex
}

func (limiter *RateLimiter) Allow(cost int) bool {
  limiter.lock.Lock()
  defer limiter.lock.Unlock()
  
  // Refill tokens based on elapsed time
  now := time.Now()
  elapsed := now.Sub(limiter.lastRefill).Seconds()
  tokensToAdd := int(elapsed * float64(limiter.refillRate))
  limiter.tokens = min(limiter.capacity, limiter.tokens + tokensToAdd)
  limiter.lastRefill = now
  
  // Check if enough tokens
  if limiter.tokens >= cost {
    limiter.tokens -= cost
    return true
  }
  
  return false
}
```

**Advantages:**
- Smooth rate limiting (no sudden traffic spikes rejected)
- Fair queuing
- Can handle bursts up to capacity

---

### 4.5 Failure Modes and Fallbacks

#### Failure Modes

| Mode | Cause | Handling |
|------|-------|----------|
| **Policy Engine Unreachable** | Network partition, PDP down | Fail closed (deny all) or fail open (allow with logging) |
| **Invalid Policy** | Malformed policy YAML/JSON | Reject update; fall back to previous policy |
| **Audit Log Full** | Storage exhausted | Alert ops; stop accepting requests until resolved |
| **High Decision Latency** | Slow policy evaluation | Implement timeout; deny if no decision in 100ms |

#### Recommended Fallback Strategy

```go
func (authz *Authorizer) CheckAccessWithFallback(ctx context.Context,
  subject, action, resource string) (bool, error) {
  
  // 1. Try primary authorization
  ctx, cancel := context.WithTimeout(ctx, 50*time.Millisecond)
  defer cancel()
  
  permit, err := authz.CheckAccess(ctx, subject, action, resource)
  if err == nil {
    return permit, nil
  }
  
  // 2. Primary failed; fall back to cache
  cached := authz.cache.Get(cacheKey(subject, resource))
  if cached != nil {
    auditLog.LogFallbackUsed(subject, action, resource, "cache")
    return cached.Can(action), nil
  }
  
  // 3. No cache; deny by default (fail closed)
  auditLog.LogFallbackDenied(subject, action, resource)
  return false, fmt.Errorf("authorization unavailable; denying by default")
}
```

---

## Section 5: Comparative Matrix of Authorization Patterns

### Feature Comparison

| Feature | RBAC | ABAC | PBAC | ReBAC | OPA | XACML |
|---------|------|------|------|-------|-----|-------|
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ | ⭐⭐☆☆☆ |
| **Granularity** | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ |
| **Scalability** | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| **Flexibility** | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Auditability** | ⭐⭐⭐⭐☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Maturity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Operational Overhead** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ | ⭐⭐⭐☆☆ | ⭐⭐☆☆☆ |

### Decision Matrix: Which Pattern to Use?

```
Decision Tree for Choosing Authorization Pattern:

1. Is simplicity critical?
   YES → RBAC (start here; add complexity later)
   NO → Continue to 2

2. Do you need complex, dynamic policies?
   YES → ABAC or OPA
   NO → Continue to 3

3. Do you need relationship-based queries?
   YES → ReBAC
   NO → Continue to 4

4. Do you need standardized compliance framework?
   YES → XACML
   NO → Use PBAC with custom DSL
```

---

## Section 6: Implementation Complexity Estimates

### Complexity Tiers

#### Tier 1: Basic RBAC (Low Complexity)
**Time to MVP**: 1-2 weeks
**Components**:
- Role definition (Admin, Editor, Viewer)
- Role assignment to users
- Permission checking at API layer
- Audit logging

**Tools/Stack**:
- Database table: `user_roles`, `role_permissions`
- Middleware for permission checking
- Basic audit logger

**Effort**: 80-120 engineering hours

#### Tier 2: Hierarchical RBAC + Resource ACLs (Medium Complexity)
**Time to MVP**: 3-4 weeks
**Components**:
- Hierarchical scope (Org → Workspace → Resource)
- Role hierarchy and inheritance
- Per-resource ACLs
- Audit logging with reasoning

**Tools/Stack**:
- Tier 1 + ReBAC concepts
- Recursive permission resolution
- Policy caching layer

**Effort**: 200-300 engineering hours

#### Tier 3: RBAC + ABAC with Embedded Policy Engine (High Complexity)
**Time to MVP**: 6-8 weeks
**Components**:
- Tier 2 + attribute evaluation
- Policy evaluation engine (Rego-inspired)
- Dynamic policy loading/versioning
- Policy unit testing framework
- Rate limiting and quotas
- Comprehensive audit logging

**Tools/Stack**:
- Tier 2 + embedded policy evaluator
- Policy language parser/evaluator
- Policy version control
- Decision caching with TTL

**Effort**: 500-800 engineering hours

#### Tier 4: Full PBAC with OPA/Policy Engine + ReBAC (Very High Complexity)
**Time to MVP**: 12+ weeks
**Components**:
- Tier 3 + external/internal policy engine
- Relationship-based access control (Zanzibar-inspired)
- Policy as code with CI/CD integration
- Policy analytics and reporting
- Fine-grained audit trail with decision reasoning

**Tools/Stack**:
- OPA or SpiceDB (or built from scratch)
- Policy language with testing framework
- Relationship graph database
- Decision logging with detailed context

**Effort**: 1200+ engineering hours

---

## Section 7: Recommended Approach for Harmonia V3

### Architecture Recommendation

**Implement a phased approach:**

#### Phase 1: Hierarchical RBAC (Months 1-2)
- Organization → Workspace → Resource hierarchy
- 3-4 core roles (admin, editor, executor, viewer)
- Role-based permission checks in API middleware
- Basic audit logging

#### Phase 2: Resource ACLs + Attributes (Months 3-4)
- Per-resource access control lists
- Subject and resource attributes (sensitivity, environment, owner)
- Attribute-based condition evaluation
- Quota enforcement

#### Phase 3: Embedded Policy Engine (Months 5-6)
- Custom declarative policy language
- Policy versioning and rollback
- Rate limiting and dynamic policies
- Comprehensive audit logging with reasoning

#### Phase 4: Advanced Features (Months 7+, future)
- Relationship-based access control
- Integration with external policy engines (OPA)
- Policy analytics and compliance reporting

### Reference Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Harmonia V3 Authorization System              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  API Request Layer                               │  │
│  │  - Authentication (JWT validation)               │  │
│  │  - Subject extraction                            │  │
│  └─────────────────┬────────────────────────────────┘  │
│                    │                                     │
│  ┌─────────────────▼────────────────────────────────┐  │
│  │  Authorization Gateway Middleware                │  │
│  │  - Extract action + resource from request        │  │
│  │  - Query Policy Decision Point                   │  │
│  │  - Log decision (audit trail)                    │  │
│  └─────────────────┬────────────────────────────────┘  │
│                    │                                     │
│  ┌─────────────────▼────────────────────────────────┐  │
│  │  Policy Decision Point (PDP)                     │  │
│  │  ┌─────────────────────────────────────────────┐│  │
│  │  │  Authorization Evaluator (Go)               ││  │
│  │  │  1. Check RBAC (role-based perms)           ││  │
│  │  │  2. Check Resource ACLs                     ││  │
│  │  │  3. Evaluate Attributes/Conditions          ││  │
│  │  │  4. Enforce Quotas & Rate Limits            ││  │
│  │  │  5. Return permit/deny + reason             ││  │
│  │  └─────────────────────────────────────────────┘│  │
│  │                                                  │  │
│  │  Data Sources:                                  │  │
│  │  - Permissions DB (roles, ACLs, attributes)    │  │
│  │  - Policy Store (YAML/JSON policies)           │  │
│  │  - Quota Cache (current usage)                 │  │
│  │  - Decision Cache (recent decisions, 30s TTL)  │  │
│  └─────────────────┬────────────────────────────────┘  │
│                    │                                     │
│          ┌─────────┴─────────┐                          │
│          │ Permit     Deny   │                          │
│          ▼                   ▼                          │
│   Continue      Return 403 Forbidden                   │
│   Request         + Audit Log                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Audit Logging System                            │  │
│  │  - Immutable append-only log                     │  │
│  │  - Full context: subject, action, resource      │  │
│  │  - Decision reasoning                           │  │
│  │  - Queryable by admins/security team            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Section 8: Integration Points with Harmonia V3

### 1. Tool Execution Authorization

```
Tool Invocation Flow:

User calls: $ harmonia execute tool_deploy --workspace ws-prod

1. CLI authenticates user (JWT token)
2. API receives request with:
   - subject: user@company.com
   - action: execute
   - resource: tool_deploy (in ws-prod)
3. Authorization Gateway checks:
   - Is user in workspace?
   - Does user have tool_executor role?
   - Is tool_deploy in allowed_tools?
   - Are rate limits exceeded?
   - Are required approvals in place?
4. If approved, execute tool with resource limits
5. Log execution to audit trail
```

### 2. Workflow Execution Authorization

Similar to tool execution, but with additional considerations:
- Workflow owner validation
- Nested tool execution authorization
- Environment-specific policies (dev vs. prod)

### 3. Workspace/Resource Management

```
Creating a new tool:
1. User submits: POST /workspaces/ws-123/tools
2. Authorization checks:
   - Does user have workspace_editor role in ws-123?
   - Is workspace at tool creation limit?
3. Tool created; default ACL: creator = owner
4. Creator can share tool by adding other users to ACL

Sharing a tool:
1. User submits: PATCH /tools/tool-abc/acl
2. Authorization checks:
   - Is user the tool owner OR workspace admin?
3. ACL updated; all users can now see tool
```

### 4. Secret/Credential Management

```
Accessing a secret:
1. Tool execution requests secret: credentials.db_password
2. Authorization checks:
   - Does tool have permission to access secret?
   - Does executor have sufficient privilege?
   - Has secret been accessed recently? (anomaly detection)
3. If approved, return decrypted secret to tool
4. Log access: subject, secret_id, timestamp, result
```

---

## Section 9: Risk Assessment

### Security Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Privilege Escalation** | Critical | Enforce least privilege; regular role audits; MFA for admin actions |
| **Unauthorized Tool Execution** | Critical | Require explicit allowlist; approval workflows for sensitive tools |
| **Credential Leakage** | Critical | Encrypt credentials at rest; audit all access; rotate keys regularly |
| **Audit Log Tampering** | High | Immutable logs; cryptographic signatures; offsite backup |
| **Bypass via Unencrypted Channel** | High | TLS for all communications; validate certificate pinning |
| **Policy Engine Compromise** | High | Code review; sandboxed evaluation; least privilege for evaluator |
| **Token Expiration Bypass** | Medium | Validate expiration on every request; revocation check for long-running operations |
| **Time-of-Check to Time-of-Use (TOCTOU)** | Medium | Lock resources during critical operations; transactional updates |

### Operational Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Policy Misconfiguration** | High | Policy unit tests; dry-run mode; gradual rollout (canary) |
| **Audit Log Disk Full** | High | Monitor disk usage; alerting; automatic cleanup of old logs |
| **PDP Latency** | Medium | Cache decisions; fallback to previous decision; timeout (deny by default) |
| **Unexpected Denials** | Medium | Comprehensive logging; decision dashboard; easy debugging tools |
| **Permission Creep** | Medium | Quarterly permission audits; JIT (just-in-time) access requests |

---

## Section 10: Real-World Production Examples

### Example 1: AWS IAM

**Pattern**: Identity-based + Resource-based policies

**Strengths**:
- Flexible condition expressions
- Cross-account access via trust relationships
- Fine-grained resource tagging

**Complexity**: High; policies can become unwieldy

**Quote from AWS Docs**: "Start with least privileges and add permissions as needed. Use managed policies where possible to reduce operational overhead."

### Example 2: Google Cloud IAM

**Pattern**: Hierarchical RBAC with attributes

**Strengths**:
- Clear role hierarchy (Organization → Folder → Project)
- Resource labels enable attribute-based conditions
- Strong consistency guarantees

**Integration Example**:
```
Organization
└── Project: prod-platform
    ├── Resource: Cloud Run service
    ├── IAM Policy: service-deployer-role
    └── Attribute: requires_approval = true (for prod)
```

### Example 3: Kubernetes RBAC

**Pattern**: Hierarchical role definitions

**Strengths**:
- Simple role + binding model
- Namespace scoping for multi-tenancy
- Declarative (YAML)

**Example**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: User
  name: alice@company.com
  apiGroup: rbac.authorization.k8s.io
```

### Example 4: Open Policy Agent (OPA) in Production

**Organizations using OPA**: Styra (creator), HashiCorp, Cloudflare, Microsoft

**Use Cases**:
- Kubernetes admission control (Gatekeeper)
- Terraform policy enforcement
- API gateway authorization

**Policy Example** (Docker image scanning):
```rego
package docker

deny[msg] {
  input.image.tag == "latest"
  msg := "Image tag 'latest' is not allowed"
}

deny[msg] {
  not startswith(input.image.registry, "us-docker.pkg.dev")
  msg := "Only images from us-docker.pkg.dev are allowed"
}
```

---

## Section 11: Recommended Policies for Harmonia V3

### Policy 1: Basic Workspace Access

```yaml
policy:
  name: "workspace-access"
  description: "Basic workspace access control"

rules:
  - name: "workspace-owner-full-access"
    condition:
      - subject.workspace_role == "owner"
    permissions: ["read", "write", "delete", "manage-users"]

  - name: "workspace-editor-edit-access"
    condition:
      - subject.workspace_role == "editor"
    permissions: ["read", "write", "execute"]

  - name: "workspace-viewer-read-only"
    condition:
      - subject.workspace_role == "viewer"
    permissions: ["read"]
```

### Policy 2: Production Deployment Governance

```yaml
policy:
  name: "production-deployment"
  description: "Require approval and MFA for production deployments"

rules:
  - name: "production-deploy-requires-approval"
    condition:
      - resource.environment == "production"
      - action == "deploy"
      - subject.has_approval == true
      - subject.approval_expires_at > now()
      - subject.has_mfa == true
    permissions: ["execute"]

  - name: "production-deploy-log-all-actions"
    condition:
      - resource.environment == "production"
      - action in ["deploy", "rollback", "scale"]
    obligations:
      - log_with_detail: true
      - notify_team_slack: true
```

### Policy 3: Secret Access Control

```yaml
policy:
  name: "secret-access"
  description: "Protect access to sensitive secrets"

rules:
  - name: "secret-owner-access"
    condition:
      - subject.id == resource.owner
      - resource.type == "secret"
    permissions: ["read", "update", "delete"]

  - name: "secret-shared-access"
    condition:
      - resource.type == "secret"
      - subject.id in resource.allowed_users
    permissions: ["read"]
    obligations:
      - audit_log_with_timestamp: true

  - name: "deny-secret-export"
    condition:
      - resource.type == "secret"
      - action == "export"
    effect: "deny"
    exceptions:
      - subject.role == "security_admin"
      - subject.has_approval == true
```

---

## Section 12: Success Criteria Checklist

### Governance Model Adoption

- [ ] **All authorization decisions logged** - 100 0x0p+0udit coverage
- [ ] **Role hierarchy defined and documented** - Clear escalation path
- [ ] **Resource ACLs implemented** - Fine-grained per-resource control
- [ ] **Attribute-based policies working** - Dynamic conditions evaluating correctly
- [ ] **Audit logs immutable and queryable** - Security team can investigate
- [ ] **Rate limiting enforced** - Quota violations prevented
- [ ] **Fallback mechanism tested** - System operates safely when PDP unavailable
- [ ] **Decision latency acceptable** - Authorization < 100ms at p99

### Operational Excellence

- [ ] **Policy unit tests written** - All policies have test coverage
- [ ] **Policy versioning implemented** - Can roll back broken policies
- [ ] **Operations runbook created** - Troubleshooting guide exists
- [ ] **Monitoring alerts configured** - Anomalies detected quickly
- [ ] **Incident response procedure defined** - Team knows how to respond
- [ ] **Documentation complete** - Operators can understand policies
- [ ] **Security review completed** - No obvious bypass techniques
- [ ] **Performance tested at scale** - Latency acceptable with 10k+ users

### Compliance & Security

- [ ] **Least privilege enforced** - Users have minimal required permissions
- [ ] **Separation of duties implemented** - Critical actions require approval
- [ ] **MFA integrated** - Sensitive operations require MFA
- [ ] **Audit retention policy** - Logs retained per regulatory requirements
- [ ] **Access review process** - Quarterly permission audits
- [ ] **Incident detection** - Anomalous access patterns flagged
- [ ] **Compliance reports generated** - Audit trails exportable for regulators

---

## Conclusion

Harmonia V3's runtime action governance should be built on a **hybrid approach combining hierarchical RBAC, ABAC, and policy-based enforcement**. This provides:

1. **Simplicity** for common use cases (RBAC foundation)
2. **Flexibility** for complex policies (ABAC conditions)
3. **Auditability** for compliance (policy versioning, audit logs)
4. **Performance** for latency-sensitive operations (caching, embedded evaluation)
5. **Scalability** to support thousands of users and resources

The phased implementation approach allows Harmonia to start with basic RBAC in Phase 1 and graduate to advanced features (ReBAC, OPA integration) in later phases as requirements evolve.

---

## References & Citations

### Standards & Frameworks
- NIST/ANSI/INCITS RBAC Standard (2004)
- OASIS XACML 3.0 (2013)
- OASIS XACML 4.0 (Committee Specification Draft 01, 2026)
- OWASP Authorization Cheat Sheet
- RFC 4876: Role-Based Access Control Model

### Production Systems
- AWS IAM Documentation (https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- Kubernetes RBAC (https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- Open Policy Agent (https://www.openpolicyagent.org/)
- Google Cloud IAM (Google Cloud documentation)
- SpiceDB (https://authzed.com/, https://github.com/authzed/spicedb)

### Research & Best Practices
- OWASP Cheat Sheet Series: Authorization (https://cheatsheetseries.owasp.org/)
- Permit.io: RBAC vs. ABAC (https://www.permit.io/blog/rbac-vs-abac)
- AuthZed Documentation (https://docs.authzed.com/)

---

## Document Metadata

**Version**: 1.0  
**Created**: 2025-04-16  
**Last Updated**: 2025-04-16  
**Status**: Research  
**Next Phase**: Design task td-8d067f (Define governance authority boundaries)  

---

*This research document is intended for Harmonia V3 architecture and design teams. It provides analysis of authorization patterns and recommendations for runtime action governance. Implementation decisions should be validated against specific Harmonia V3 requirements.*