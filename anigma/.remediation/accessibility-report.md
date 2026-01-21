# Accessibility Violations Report

**Generated**: 2026-01-07T07:58:41Z  
**Total Violations**: 83

## Breakdown

| Type | Count |
|------|-------|
| Buttons | 60 |
| TextFields | 10 |
| Toggles | 6 |
| Pickers | 7 |

## Top 20 Files (by violation count)

```
  16 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/SourceConnectionWizard.swift
  13 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/DevelopView.swift
   7 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/SourceConnectionView.swift
   6 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/ProjectPlanningView.swift
   5 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/CompassView.swift
   5 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Components/JobCenterPanel.swift
   5 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Components/GovernanceStrip.swift
   4 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/StudioView.swift
   4 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/AskView.swift
   3 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/PreflightGate.swift
   3 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Components/TrustBoundaryPanel.swift
   3 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Components/PrivacyConsole.swift
   2 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/ContractDashboardView.swift
   2 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Components/TransformPreview.swift
   1 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/ProjectsView.swift
   1 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/JobCenterView.swift
   1 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/InboxView.swift
   1 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/DevelopSearchView.swift
   1 /Users/user/Developer/GitHub/Anigma/Sources/AnigmaAppMac/Surfaces/ActivityView.swift
```

## Next Steps

1. Review priority files first (highest violation count)
2. Add `.accessibilityLabel()` to each interactive element
3. Test with VoiceOver (Cmd+F5)
4. Re-run detection to verify fixes

## Detailed Violations

### Buttons
See: `.remediation/violations-buttons.txt`

### TextFields
See: `.remediation/violations-textfields.txt`

### Toggles
See: `.remediation/violations-toggles.txt`

### Pickers
See: `.remediation/violations-pickers.txt`
