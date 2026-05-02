# UI Enhancements for Structured Violations

## Current State

The governance system already produces `GovernanceViolation` with:
- `checkId` (e.g., "operating-mode", "kill-switch", "admin-check")
- `modeSource` (e.g., "project:alpha", "global", "default")
- `violationId` (UUID for correlation)
- `principal` + `projectId`

`IndexProgress` already carries `violation: GovernanceViolation?` field.

## What's Missing

The UI doesn't display this structured data yet. It either:
- Shows nothing (silent failure)
- Shows generic error message from `lastError` string

## Quick Win: Add Denial Banner Component

Create a reusable `DenialBannerView` that takes a `GovernanceViolation?` and shows:

```swift
struct DenialBannerView: View {
    let violation: GovernanceViolation?
    @State private var showingDetails = false
    
    var body: some View {
        if let v = violation {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Governance Denial")
                            .font(.headline)
                        
                        Text("Blocked by: \(v.checkId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(showingDetails ? "Hide Details" : "Show Details") {
                        showingDetails.toggle()
                    }
                    .buttonStyle(.link)
                }
                
                if showingDetails {
                    Divider()
                    
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12) {
                        GridRow {
                            Text("Check:").fontWeight(.medium)
                            Text(v.checkId)
                        }
                        GridRow {
                            Text("Mode Source:").fontWeight(.medium)
                            Text(v.modeSource ?? "unknown")
                        }
                        GridRow {
                            Text("Principal:").fontWeight(.medium)
                            Text("\(v.principal.id) (\(v.principal.displayName))")
                        }
                        GridRow {
                            Text("Project:").fontWeight(.medium)
                            Text(v.projectId ?? "global")
                        }
                        GridRow {
                            Text("Violation ID:").fontWeight(.medium)
                            HStack {
                                Text(v.violationId)
                                    .font(.caption.monospaced())
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(v.violationId, forType: .string)
                                }
                                .buttonStyle(.link)
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
```

## Where to Use It

### IndexPanelView

After the progress display, add:

```swift
// Show denial banner if indexing failed due to governance
if let progress = model.indexingState.progress,
   let violation = progress.violation {
    DenialBannerView(violation: violation)
}
```

### MemoPanelView

After the save button, add:

```swift
// Show denial if memo save was blocked
if let lastDenial = model.memoState.lastDenial {
    DenialBannerView(violation: lastDenial)
}
```

(You'll need to add `lastDenial: GovernanceViolation?` to `AppModel.MemoState`)

### RecallPanelView

Recall shouldn't be denied in readOnly, but if it fails for governance reasons:

```swift
if let denial = model.recallState.lastDenial {
    DenialBannerView(violation: denial)
}
```

## How to Extract Violation in AppModel

When catching errors from the client, use the extractor:

```swift
} catch {
    // Extract structured violation if present
    if let violation = GovernanceViolationExtractor.extract(from: error) {
        self.memoState.lastDenial = violation
    } else {
        // Generic error fallback
        self.lastError = error.localizedDescription
    }
}
```

## Benefits

1. **User trust**: They see exactly which rule fired
2. **Debuggability**: Violation ID is copyable for logs/support
3. **Transparency**: Mode source shows why it happened (project vs global)
4. **Consistency**: Same denial format everywhere (index, memo, recall)

## Implementation Priority

1. Add `DenialBannerView.swift` to AnigmaAppMac sources
2. Add it to `Package.swift` sources list for AnigmaAppMacExecutable
3. Add `lastDenial` fields to AppModel state structs
4. Update error handlers to extract violations
5. Place banner in all three panels (index, memo, recall)

Total effort: ~30 minutes, massive UX improvement.
