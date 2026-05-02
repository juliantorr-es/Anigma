# 08: Storage & Persistence Layer: Mechanics
- **Governance Persistence**: All database writes occur via `GovernanceLogger` which stages to `StorageCore`.
- **Row-Level Security (RLS)**: Enforced via `GovernedPersistence_RLS.sql` at the SQL level before any data leaves the storage boundary.
