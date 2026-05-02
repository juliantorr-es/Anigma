# Anigma macOS App Bundle

## Overview
A proper macOS app bundle (.app) that launches a real SwiftUI GUI application for Anigma, replacing the placeholder script that only showed installation status.

## Structure
```
Anigma.app/
└── Contents/
    ├── Info.plist          # App metadata and configuration
    ├── PkgInfo             # macOS bundle type info
    ├── MacOS/
    │   └── AnigmaAppMac    # SwiftUI executable
    └── Resources/
        ├── AppIcon.icns    # App icon placeholder
        └── AppIcon.png     # PNG version of icon
```

## Features
- **Real SwiftUI Interface**: Native macOS app with dashboard, sidebar navigation
- **Daemon Status Monitoring**: Connects to and displays Anigma daemon status
- **Document Library**: Browse and manage documents
- **Observatorium Dashboard**: System monitoring and alerting
- **Proper App Bundle**: Follows macOS conventions with correct structure
- **Menu Integration**: Native macOS menu bar and commands
- **Settings Window**: Dedicated preferences window

## Building
Use the provided build script:
```bash
./Scripts/build_mac_app.sh
```

Or build manually:
```bash
swift build --product AnigmaAppMac
cp .build/debug/AnigmaAppMac build/Anigma.app/Contents/MacOS/
```

## Running
```bash
open build/Anigma.app
```

## Key Improvements from Placeholder
1. **Real GUI**: SwiftUI app instead of bash dialog
2. **Navigation**: Sidebar with multiple sections
3. **State Management**: Observable app state
4. **Daemon Integration**: Actual connection to Anigma daemon
5. **Native Experience**: Proper macOS app bundle structure
6. **Extensible**: Easy to add new features and views

## Technical Details
- Swift 6 with strict concurrency
- SwiftUI for modern macOS interface
- Observable pattern for state management
- Task-based async operations
- macOS 14.0+ target
