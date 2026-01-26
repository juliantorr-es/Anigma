# macOS Application

## Entry and Composition
- App entry point is `App/MacApp/AnigmaApp.swift`, which wires `RootView()` with `AppStore` and `AppState` environments.
- Global commands are provided via `App/MacApp/AnigmaCommands.swift` and settings live in `App/MacApp/SettingsView.swift`.

## Primary Surfaces
- User-facing screens are organized under `App/MacApp/Surfaces` (for example `AskView.swift`, `ProjectsView.swift`, `StudioView.swift`).
- The main shell composition lives in `App/MacApp/RootView.swift` and `App/MacApp/WorkspaceView.swift`.

## Roles and Shells
- Role-based shells exist under `App/MacApp/Roles`, including admin, developer, worker, and standard user shells.
- Role mapping is defined in `App/MacApp/AnigmaRoles.swift`.

## Services and State
- App services live under `App/MacApp/Services` (authentication, git, workspace, bookmarks).
- Governance-related UI components are in `App/MacApp/Governance` and `App/MacApp/Components` (for example `GovernanceStrip.swift`).
- Daemon connectivity is handled in `App/MacApp/DaemonHost.swift`.

## Key References
- `App/MacApp/AnigmaApp.swift`
- `App/MacApp/Surfaces`
- `App/MacApp/Services`
