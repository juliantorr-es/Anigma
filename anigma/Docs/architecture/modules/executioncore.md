> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# ExecutionCore

## Overview

ExecutionCore is a Swift module in the Anigma ecosystem with **1424 lines of code** across **6 files**.

## Statistics

- **Public Types**: 23
- **Public Functions**: 31  
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


### CommandLedger.swift

- **Lines**: 295
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `struct CommandLedgerWire` (line 16)
- `struct LedgerFilter` (line 63)



**Public Functions:**
- `append` (line 107)
- `read` (line 148)
- `getBySession` (line 190)
- `getByAgent` (line 196)
- `getByKind` (line 202)
- `appendLegacy` (line 273)


### ExecutionCore+Exports.swift

- **Lines**: 187
- **Public Types**: 5
- **Public Functions**: 6


**Public Types:**
- `enum PraxisCompatibility` (line 27)
- `enum CommandLedgerCompatibility` (line 71)
- `enum ExecutionCoreFactory` (line 102)
- `enum ExecutionCoreInfo` (line 139)
- `enum ExecutionCoreConstants` (line 172)



**Public Functions:**
- `createLegacyReceipt` (static) (line 29)
- `convertLegacyDecision` (static) (line 54)
- `createLegacyEntry` (static) (line 73)
- `createReceiptEngine` (static) (line 104)
- `createPhaseGateEngine` (static) (line 113)
- `createCommandLedger` (static) (line 128)


### PhaseGateEngine.swift

- **Lines**: 220
- **Public Types**: 3
- **Public Functions**: 1


**Public Types:**
- `struct PolicyDecision` (line 16)
- `protocol PolicyEvaluator` (line 40)
- `enum PhaseGateError` (line 202)



**Public Functions:**
- `attemptTransition` (line 79)


### ReceiptEngine.swift

- **Lines**: 229
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `recordDecision` (line 29)
- `recordPhaseTransition` (line 83)
- `retrieveReceipt` (line 146)
- `listReceipts` (line 151)
- `verifyReceipt` (line 156)


### ReceiptTypes.swift

- **Lines**: 221
- **Public Types**: 6
- **Public Functions**: 3


**Public Types:**
- `struct ReceiptWire` (line 16)
- `enum ReceiptDecision` (line 74)
- `struct PhaseTransitionWire` (line 93)
- `protocol ReceiptSigner` (line 148)
- `protocol ReceiptStore` (line 158)
- `struct ReceiptFilter` (line 173)



**Public Functions:**
- `deterministicJSON` (line 199)
- `contentHash` (line 207)
- `deterministicJSON` (line 215)


### Transport.swift

- **Lines**: 272
- **Public Types**: 7
- **Public Functions**: 10


**Public Types:**
- `struct TransportMessage` (line 16)
- `struct TransportResponse` (line 58)
- `enum TransportOutcome` (line 90)
- `struct TransportError` (line 107)
- `enum TransportErrorCategory` (line 125)
- `protocol TransportProtocol` (line 149)
- `enum TransportType` (line 176)



**Public Functions:**
- `register` (line 205)
- `unregister` (line 210)
- `getTransport` (line 215)
- `listTransports` (line 220)
- `getTransports` (line 225)
- `startAll` (line 232)
- `stopAll` (line 239)
- `deterministicJSON` (line 250)
- `contentHash` (line 258)
- `deterministicJSON` (line 266)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
