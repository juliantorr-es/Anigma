# DatabaseCore

## Overview

DatabaseCore is a Swift module in the Anigma ecosystem with **2036 lines of code** across **14 files**.

## Statistics

- **Public Types**: 26
- **Public Functions**: 66  
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

- `ContractsCore`

## File Structure


### ArtifactStore.swift

- **Lines**: 140
- **Public Types**: 1
- **Public Functions**: 3


**Public Types:**
- `struct PersistedArtifact` (line 6)



**Public Functions:**
- `putArtifactIdempotent` (line 46)
- `fetchArtifact` (line 79)
- `fetchArtifacts` (line 94)


### DatabaseActor.swift

- **Lines**: 513
- **Public Types**: 7
- **Public Functions**: 17


**Public Types:**
- `struct DatabaseMetrics` (line 14)
- `enum DatabaseParameter` (line 397)
- `enum DatabaseError` (line 405)
- `enum TransactionMode` (line 411)
- `enum CheckpointMode` (line 417)
- `enum DatabaseValue` (line 424)
- `struct DatabaseRow` (line 470)



**Public Functions:**
- `open` (line 56)
- `close` (line 82)
- `query` (line 90)
- `execute` (line 170)
- `executeAsync` (line 220)
- `transaction` (line 228)
- `transaction` (line 237)
- `getMetrics` (line 287)
- `checkpointWal` (line 330)
- `checkpointIfWalLarge` (line 348)
- `resetMetrics` (line 379)
- `value` (line 477)
- `string` (line 481)
- `int` (line 485)
- `int64` (line 489)
- `double` (line 493)
- `data` (line 497)


### DatabaseConfiguration.swift

- **Lines**: 90
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `enum DatabaseConfiguration` (line 12)



**Public Functions:**
- `defaultDatabasePath` (static) (line 18)
- `printDatabasePathInfo` (static) (line 80)


### DatabaseParameter+Extensions.swift

- **Lines**: 58
- **Public Types**: 1
- **Public Functions**: 12


**Public Types:**
- `enum DatabaseParameterEncodingError` (line 4)



**Public Functions:**
- `dbpJSON` (line 10)
- `dbpJSON` (line 20)
- `dbp` (line 30)
- `dbp` (line 33)
- `dbp` (line 36)
- `dbpTime` (line 39)
- `dbp` (line 42)
- `dbp` (line 45)
- `dbp` (line 48)
- `dbp` (line 51)
- `dbp` (line 54)
- `dbp` (line 57)


### DatabaseValue+Extensions.swift

- **Lines**: 43
- **Public Types**: 0
- **Public Functions**: 0





### Hashing.swift

- **Lines**: 24
- **Public Types**: 2
- **Public Functions**: 3


**Public Types:**
- `enum Hashing` (line 4)
- `struct SQLIn` (line 16)



**Public Functions:**
- `sha256Hex` (static) (line 5)
- `sha256Hex` (static) (line 10)
- `sqlIn` (line 21)


### JobQueue.swift

- **Lines**: 352
- **Public Types**: 3
- **Public Functions**: 9


**Public Types:**
- `enum RunContractJobStatus` (line 5)
- `struct RunContractJobPayload` (line 23)
- `struct RunContractJobRecord` (line 53)



**Public Functions:**
- `enqueue` (line 104)
- `enqueueIdempotent` (line 123)
- `dequeueNextReady` (line 150)
- `markCompleted` (line 176)
- `markFailed` (line 185)
- `markQuarantined` (line 195)
- `fetchJobs` (line 205)
- `fetch` (line 218)
- `pendingCount` (line 232)


### MLOutputCache.swift

- **Lines**: 184
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `struct MLOutputRecord` (line 98)
- `struct DocumentUnit` (line 155)



**Public Functions:**
- `generateCacheKey` (line 21)
- `hasCachedOutput` (line 46)
- `getCachedOutput` (line 51)
- `storeOutput` (line 56)
- `markOutputVerified` (line 83)
- `initializeMLOutputCache` (line 127)


### MigrationRegistry.swift

- **Lines**: 107
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `enum MigrationRegistry` (line 4)



**Public Functions:**
- `applyMigrations` (static) (line 6)


### ReceiptStore.swift

- **Lines**: 130
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `putReceiptIdempotent` (line 27)
- `fetchReceipts` (line 65)
- `fetchSatisfiedReceipt` (line 80)
- `fetchReceipt` (line 99)
- `fetchAnyReceipt` (line 113)


### Retrieval/HybridRetrieveQuery.swift

- **Lines**: 194
- **Public Types**: 2
- **Public Functions**: 1


**Public Types:**
- `protocol EmbeddingQueryProvider` (line 7)
- `struct HybridRetrieveQuery` (line 11)



**Public Functions:**
- `run` (line 20)


### Retrieval/RetrievalModels.swift

- **Lines**: 50
- **Public Types**: 5
- **Public Functions**: 0


**Public Types:**
- `enum RetrievalMode` (line 3)
- `struct RetrievalRequest` (line 9)
- `enum RetrievalSource` (line 31)
- `struct RetrievalHit` (line 37)
- `enum RetrievalError` (line 46)




### SQLitePolicy.swift

- **Lines**: 70
- **Public Types**: 0
- **Public Functions**: 5




**Public Functions:**
- `bindText` (line 17)
- `bindBlob` (line 24)
- `bindUUID` (line 34)
- `bindTextDangerouslyWithStaticLifetime` (line 48)
- `bindBlobDangerouslyWithStaticLifetime` (line 56)


### TestDatabase.swift

- **Lines**: 81
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct TestDatabase` (line 14)



**Public Functions:**
- `openDatabase` (line 28)
- `cleanup` (line 63)


