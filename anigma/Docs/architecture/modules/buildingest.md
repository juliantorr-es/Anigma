# BuildIngest

## Overview

BuildIngest is a Swift module in the Anigma ecosystem with **1328 lines of code** across **4 files**.

## Statistics

- **Public Types**: 15
- **Public Functions**: 15  
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

## File Structure


### BuildIngestCore.swift

- **Lines**: 398
- **Public Types**: 6
- **Public Functions**: 9


**Public Types:**
- `struct BuildIngestService` (line 15)
- `struct DocumentUnitRecord` (line 126)
- `struct BuildSessionRecord` (line 135)
- `struct SwiftDiagnostic` (line 145)
- `struct GitState` (line 374)
- `enum BuildIngestError` (line 386)



**Public Functions:**
- `ingestDocumentationDefaults` (line 23)
- `ingestDoc` (line 37)
- `queryDocsSummary` (line 58)
- `createBuildSessionFingerprint` (line 63)
- `parseSwiftDiagnostics` (line 82)
- `insertDocumentUnit` (line 165)
- `insertBuildSession` (line 183)
- `insertSwiftDiagnostic` (line 203)
- `queryDocumentUnits` (line 231)


### BuildIngestTypes.swift

- **Lines**: 288
- **Public Types**: 9
- **Public Functions**: 0


**Public Types:**
- `struct DocumentUnitRecord` (line 14)
- `struct BuildSessionRecord` (line 40)
- `struct SwiftDiagnostic` (line 69)
- `struct GitState` (line 116)
- `struct BuildResult` (line 151)
- `struct Diagnostic` (line 171)
- `enum BuildIngestError` (line 222)
- `struct BuildConfiguration` (line 248)
- `struct BuildStatistics` (line 271)




### DatabaseExtensions.swift

- **Lines**: 196
- **Public Types**: 0
- **Public Functions**: 6




**Public Functions:**
- `insertDocumentUnit` (line 18)
- `insertBuildSession` (line 36)
- `insertSwiftDiagnostic` (line 56)
- `queryDocumentUnits` (line 84)
- `updateBuildSession` (line 115)
- `storeDiagnostic` (line 149)


### main.swift

- **Lines**: 446
- **Public Types**: 0
- **Public Functions**: 0





