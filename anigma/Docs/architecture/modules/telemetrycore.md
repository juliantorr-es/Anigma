> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# TelemetryCore

## Overview

TelemetryCore is a Swift module in the Anigma ecosystem with **1082 lines of code** across **7 files**.

## Statistics

- **Public Types**: 22
- **Public Functions**: 30  
- **Components**: 0
- **Systems**: 0
- **Services**: 0

## Architecture

### Components
No components found

### Systems
No systems found

### Services
No services found

## Dependencies

No internal dependencies

## File Structure


### Redaction.swift

- **Lines**: 198
- **Public Types**: 4
- **Public Functions**: 3


**Public Types:**
- `struct Redaction` (line 12)
- `struct RedactionPolicy` (line 70)
- `enum RedactionLevel` (line 91)
- `struct RedactedTelemetryEvent` (line 126)



**Public Functions:**
- `apply` (static) (line 18)
- `encode` (line 119)
- `encode` (line 183)


### Sampling.swift

- **Lines**: 103
- **Public Types**: 3
- **Public Functions**: 3


**Public Types:**
- `struct Sampling` (line 12)
- `struct SamplingConfiguration` (line 60)
- `enum Environment` (line 66)



**Public Functions:**
- `shouldSample` (static) (line 14)
- `samplingRate` (line 95)
- `shouldAlwaysSample` (line 100)


### TelemetryClient.swift

- **Lines**: 232
- **Public Types**: 3
- **Public Functions**: 8


**Public Types:**
- `struct TelemetryConfiguration` (line 180)
- `enum Environment` (line 185)
- `struct TelemetryStatistics` (line 205)



**Public Functions:**
- `emit` (line 24)
- `emitTrace` (line 43)
- `emitError` (line 65)
- `emitToolExecution` (line 92)
- `flush` (line 148)
- `getStatistics` (line 169)
- `forDevelopment` (static) (line 215)
- `forProduction` (static) (line 226)


### TelemetryError.swift

- **Lines**: 88
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `enum TelemetryError` (line 9)



**Public Functions:**
- `encode` (line 67)


### TelemetryEvent.swift

- **Lines**: 92
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `struct TelemetryEvent` (line 12)
- `enum TelemetryCategory` (line 38)
- `enum PrivacyClassification` (line 50)



**Public Functions:**
- `encode` (line 76)


### TelemetrySink.swift

- **Lines**: 220
- **Public Types**: 4
- **Public Functions**: 11


**Public Types:**
- `struct WireRedactedEvent` (line 16)
- `protocol TelemetrySink` (line 41)
- `struct FileTelemetrySink` (line 57)
- `struct ConsoleTelemetrySink` (line 147)



**Public Functions:**
- `handle` (line 71)
- `flush` (line 97)
- `handle` (line 115)
- `flush` (line 126)
- `getAllEvents` (line 131)
- `clear` (line 136)
- `getEvents` (line 141)
- `handle` (line 159)
- `flush` (line 169)
- `handle` (line 186)
- `flush` (line 204)


### TelemetryValue.swift

- **Lines**: 149
- **Public Types**: 4
- **Public Functions**: 3


**Public Types:**
- `enum TelemetryValue` (line 13)
- `struct TelemetryTag` (line 71)
- `struct TelemetryHash` (line 110)
- `enum Algorithm` (line 111)



**Public Functions:**
- `encode` (line 27)
- `encode` (line 104)
- `encode` (line 139)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
