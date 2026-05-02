> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# ProvenanceSigning

## Overview

ProvenanceSigning is a Swift module in the Anigma ecosystem with **408 lines of code** across **1 files**.

## Statistics

- **Public Types**: 2
- **Public Functions**: 13  
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

- `AnigmaCore`

## File Structure


### ProvenanceSigning.swift

- **Lines**: 408
- **Public Types**: 2
- **Public Functions**: 13


**Public Types:**
- `struct ProvenanceSignature` (line 17)
- `enum ProvenanceError` (line 305)



**Public Functions:**
- `verify` (line 45)
- `getSigningKey` (line 64)
- `getPublicKeyString` (line 111)
- `sign` (line 119)
- `signMigration` (line 126)
- `verify` (line 167)
- `store` (line 209)
- `retrieve` (line 225)
- `getSignatures` (line 236)
- `process` (line 277)
- `verifyFromCLI` (static) (line 329)
- `listFromCLI` (static) (line 356)
- `logProvenanceOperation` (line 398)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
