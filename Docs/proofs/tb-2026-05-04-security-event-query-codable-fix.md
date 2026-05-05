# SecurityEventQuery Codable Fix

## Issue
The `SecurityEventQuery` struct in `SecurityEventsContracts` did not conform to Codable because its `dateRange` property used the tuple type `(from: Date, to: Date)?`, which does not automatically conform to Codable.

## Root Cause
Swift's Codable synthesis cannot automatically handle tuple types with named elements like `(from: Date, to: Date)`. Tuples do not synthesize Codable conformance for their elements.

## Solution
Created a dedicated `DateRange` struct with `from: Date` and `to: Date` properties that conforms to Codable. Changed `SecurityEventQuery.dateRange` from `(from: Date, to: Date)?` to `DateRange?`.

## Changes

### File: `anigma/Packages/ContractsCore/Sources/SecurityEventsContracts/SecurityEventStore.swift`

Added new `DateRange` struct:
```swift
/// A date range for filtering events.
public struct DateRange: Sendable, Codable {
    public let from: Date
    public let to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}
```

Updated `SecurityEventQuery`:
- Changed `dateRange: (from: Date, to: Date)?` to `dateRange: DateRange?`
- Changed initializer parameter from `dateRange: (from: Date, to: Date)? = nil` to `dateRange: DateRange? = nil`

## Verification

### Before
- Build errors: 27 → 4 (from previous slice)
- 4 errors in SecurityEventQuery related to tuple not being Codable

### After
- Build errors: 4 → new errors unrelated to SecurityEventQuery
- No SecurityEventQuery errors in build output
- Confirmed with: `swift build 2>&1 | grep -i "securityeventquery"` (no results)

## Tier Compliance
- `DateRange` struct added in ContractsCore (Tier 1)
- No dependency on DatabaseCore (which has its own DateRange in Tier 2)
- Maintains portable contract status

## Impact
- Binary breaking change for any code using the tuple constructor
- No existing call sites found in codebase (searched for `SecurityEventQuery(`)
- Safe to apply as this appears to be unused in current codebase
