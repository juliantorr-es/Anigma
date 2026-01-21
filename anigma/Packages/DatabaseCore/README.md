# DatabaseCore

**GRDB-based persistence layer with schema management and migrations**

DatabaseCore provides a robust, actor-based database abstraction built on GRDB, with support for schema versioning, migrations, and type-safe queries.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DatabaseCore                          │
├─────────────────────────────────────────────────────────┤
│  DatabaseManager (Actor)                                 │
│  ├─ Connection Pool                                      │
│  ├─ Schema Versioning                                    │
│  ├─ Migration Engine                                     │
│  └─ Transaction Management                               │
├─────────────────────────────────────────────────────────┤
│  GRDB.swift                                              │
│  ├─ SQLite Engine                                        │
│  ├─ Type-Safe Queries                                    │
│  └─ FetchableRecord / PersistableRecord                  │
└─────────────────────────────────────────────────────────┘
```

## Features

- **Actor-Based**: Thread-safe database access
- **Schema Versioning**: Automatic schema migrations
- **Type-Safe**: GRDB's FetchableRecord and PersistableRecord
- **Transactions**: ACID-compliant transaction support
- **Multiple Schemas**: Support for specialized schemas (Evidence, CourtSafe, etc.)
- **Audit Trail**: Integration with ContractsCore audit logging

## Core Types

### DatabaseManager

```swift
public actor DatabaseManager {
    func initialize(at path: String) async throws
    func read<T>(_ operation: @Sendable (Database) throws -> T) async throws -> T
    func write<T>(_ operation: @Sendable (Database) throws -> T) async throws -> T
    func migrate(to version: Int) async throws
}
```

### Schema Management

```swift
public struct SchemaVersion: Codable {
    let version: Int
    let appliedAt: Date
    let description: String
}

public protocol Migration {
    var version: Int { get }
    var description: String { get }
    func up(db: Database) throws
    func down(db: Database) throws
}
```

## Available Schemas

| Schema | Purpose | Tables |
|--------|---------|--------|
| **Master** | Core entities and metadata | entities, components, jobs |
| **Evidence** | Evidence chain and provenance | evidence_entries, evidence_chain |
| **EvidenceBundle** | Bundled evidence packages | bundles, bundle_items |
| **BuildDiagnostics** | Build and compilation data | builds, diagnostics, errors |
| **CourtSafe** | Legal compliance records | court_records, compliance_logs |
| **DocumentUnits** | Document processing units | documents, pages, annotations |

## Usage Examples

### Basic Database Operations

```swift
import DatabaseCore

let dbManager = DatabaseManager()
try await dbManager.initialize(at: "/path/to/database.db")

// Read operation
let users = try await dbManager.read { db in
    try User.fetchAll(db)
}

// Write operation
try await dbManager.write { db in
    var user = User(name: "Alice", email: "alice@example.com")
    try user.insert(db)
}
```

### Defining Models

```swift
struct User: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var email: String
    var createdAt: Date
    
    static let databaseTableName = "users"
}
```

### Migrations

```swift
struct CreateUsersTable: Migration {
    let version = 1
    let description = "Create users table"
    
    func up(db: Database) throws {
        try db.create(table: "users") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("email", .text).notNull().unique()
            t.column("created_at", .datetime).notNull()
        }
    }
    
    func down(db: Database) throws {
        try db.drop(table: "users")
    }
}

// Apply migration
try await dbManager.migrate(to: 1)
```

### Transactions

```swift
try await dbManager.write { db in
    try db.inTransaction {
        // Multiple operations in a transaction
        try user1.insert(db)
        try user2.insert(db)
        return .commit
    }
}
```

### Complex Queries

```swift
struct UserWithPosts: Decodable, FetchableRecord {
    var user: User
    var postCount: Int
}

let results = try await dbManager.read { db in
    try User
        .annotated(with: User.posts.count)
        .asRequest(of: UserWithPosts.self)
        .fetchAll(db)
}
```

## Thread Safety

- **DatabaseManager** is an `actor` - all operations are serialized
- **Read operations** can run concurrently
- **Write operations** are serialized through actor isolation
- **GRDB** handles connection pooling internally

## Schema Files

All schema SQL files are embedded as resources:

- `Schema_Master.sql` - Core schema
- `Schema_Evidence.sql` - Evidence chain
- `Schema_EvidenceBundle.sql` - Evidence bundles
- `Schema_BuildDiagnostics.sql` - Build data
- `Schema_CourtSafe.sql` - Legal compliance
- `Schema_DocumentUnits.sql` - Document processing

## Migration Strategy

1. **Version-based**: Each migration has a version number
2. **Sequential**: Migrations applied in order
3. **Reversible**: Each migration has `up` and `down`
4. **Tracked**: Applied migrations recorded in schema_versions table

## Performance Considerations

- **Connection Pooling**: GRDB manages connection pool
- **Prepared Statements**: Queries are cached and reused
- **Batch Operations**: Use transactions for bulk inserts
- **Indexes**: Create indexes for frequently queried columns

## Best Practices

1. **Use Transactions**: Group related writes
2. **Index Wisely**: Balance query speed vs write cost
3. **Avoid N+1**: Use joins and eager loading
4. **Test Migrations**: Always test up and down migrations
5. **Backup First**: Backup database before migrations

## Testing

```swift
import XCTest
@testable import DatabaseCore

final class DatabaseTests: XCTestCase {
    var dbManager: DatabaseManager!
    
    override func setUp() async throws {
        dbManager = DatabaseManager()
        try await dbManager.initialize(at: ":memory:")
    }
    
    func testUserCRUD() async throws {
        // Create
        try await dbManager.write { db in
            var user = User(name: "Test", email: "test@example.com")
            try user.insert(db)
        }
        
        // Read
        let users = try await dbManager.read { db in
            try User.fetchAll(db)
        }
        
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Test")
    }
}
```

## Dependencies

- **GRDB.swift**: SQLite wrapper and ORM
- **ContractsCore**: Audit logging integration

## See Also

- [GRDB Documentation](https://github.com/groue/GRDB.swift)
- [Migration Guide](../../Docs/database-migrations.md)
- [Schema Design](../../Docs/database-schema.md)

## License

Part of the Anigma project. See LICENSE for details.
