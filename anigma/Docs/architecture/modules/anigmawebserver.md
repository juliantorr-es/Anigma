> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# AnigmaWebServer

## Overview

AnigmaWebServer is a Swift module in the Anigma ecosystem with **608 lines of code** across **1 files**.

## Statistics

- **Public Types**: 19
- **Public Functions**: 0  
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

- `DatabaseCore`
- `ContractsCore`
- `AnigmaCore`

## File Structure


### AnigmaWebServer.swift

- **Lines**: 608
- **Public Types**: 19
- **Public Functions**: 0


**Public Types:**
- `struct PlanSubmissionRequest` (line 378)
- `struct PlanSubmissionResponse` (line 386)
- `struct PlanInspectionRequest` (line 395)
- `struct PlanInspectionResponse` (line 401)
- `struct PlanExecutionRequest` (line 407)
- `struct PlanExecutionResponse` (line 414)
- `struct BundleExportRequest` (line 422)
- `struct BundleExportResponse` (line 429)
- `enum ResponseStatus` (line 437)
- `enum RejectionReason` (line 444)
- `enum ExecutionStatus` (line 451)
- `struct PlanIntegrityVerification` (line 460)
- `struct EvidenceIntegrityVerification` (line 467)
- `struct EvidenceDependencyViolation` (line 473)
- `struct LeaseVerification` (line 480)
- `enum LeaseRejectionReason` (line 486)
- `struct OutputEvidenceBinding` (line 492)
- `struct CourtSafeBundle` (line 499)
- `struct HealthResponse` (line 557)





Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
