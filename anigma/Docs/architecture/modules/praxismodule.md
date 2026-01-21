# PraxisModule

## Overview

PraxisModule is a Swift module in the Anigma ecosystem with **434 lines of code** across **6 files**.

## Statistics

- **Public Types**: 9
- **Public Functions**: 4  
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


### PraxisToolIntegration.swift

- **Lines**: 106
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct PraxisToolIntegration` (line 6)



**Public Functions:**
- `registerTools` (static) (line 7)


### RepoIdentityGate/GitProbe.swift

- **Lines**: 47
- **Public Types**: 3
- **Public Functions**: 0


**Public Types:**
- `struct GitProbe` (line 3)
- `protocol GitProbing` (line 34)
- `enum RepoIdentityGateFailure` (line 38)




### RepoIdentityGate/RepoIdentityGate.swift

- **Lines**: 101
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `struct RepoIdentityGateResult` (line 3)
- `struct RepoIdentityGate` (line 17)



**Public Functions:**
- `evaluate` (line 24)


### RepoIdentityGate/RepoIdentityGateTicketing.swift

- **Lines**: 71
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct RepoIdentityGateTicketPayload` (line 4)




### RepoIdentityGate/RepoIdentityPolicy.swift

- **Lines**: 38
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct RepoIdentityPolicy` (line 3)



**Public Functions:**
- `load` (static) (line 33)


### RepoIdentityGate/ShellGitProber.swift

- **Lines**: 71
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct ShellGitProber` (line 3)



**Public Functions:**
- `probe` (line 6)


