# Anigma Data Governance

> Local-first, governed by design. This document is informational; data-sharing always requires separate written terms.

## Philosophy
- **Local-first**: Runs primarily on user-owned machines, with local models by default.  
- **Governance & audit**: Sessions produce governance traces and audit trails; actions are policy-checked.  
- **Self-improvement, but controlled**: The system can tune itself using scouts, traces, and distilled artifacts—but only within user-approved boundaries.

## Data Categories
- **Runtime telemetry/logs**: Operational logs, performance metrics, basic diagnostics.  
- **Governance traces**: Policy decisions, approvals/denials, bandit selections, tool usage summaries.  
- **Self-improvement artifacts**: Aggregated stats, distilled patterns, model deltas, anonymized traces, and similar outputs derived from use.

## Data Modes

### Shared-learning mode
- User/organization explicitly opts in.  
- Certain self-improvement artifacts (e.g., anonymized traces, aggregated stats, distilled patterns, model deltas) may be shared back to the author.  
- Always subject to:  
  - Prior data-protection review and stakeholder approval on the user’s side.  
  - Anonymization/pseudonymization where feasible.  
  - A governing DPA or equivalent agreement.  
- Benefits: Potentially lower pricing/expanded features for contributors.

### Strict-silo mode
- All self-improvement data stays local.  
- No sharing of logs, traces, artifacts, or model deltas.  
- Typically higher pricing/support because the user benefits without contributing edge-case data. This is the default for regulated/academic environments (e.g., CCSF/DSPS) unless a separate data-sharing agreement is in place.

## Consent and Safety
- Sharing is **opt-in** and requires a separate agreement (e.g., Training Data Addendum).  
- No personally identifiable information or protected categories should be shared without explicit, informed consent and legal review.  
- Users can revoke sharing prospectively (existing trained models/deltas are not retroactively untrained unless separately agreed).

## Commercial Use Reminder
- If Anigma is used to reduce costs, replace paid tools, or support revenue-generating workflows, it is “commercial use” and requires appropriate licensing, regardless of data mode.
