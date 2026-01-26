# Anigma macOS Installer

This directory contains the complete macOS installer package for Anigma applications.

## Components

### 1. AnigmaDaemon.app
- **Purpose**: Background service daemon
- **Location**: `/Applications/AnigmaDaemon.app`
- **Features**:
  - Starts automatically via LaunchAgent
  - Runs in background as LSUIElement (no Dock icon)
  - Logs to `/tmp/com.anigma.daemon.log`
  - Includes uninstall script

### 2. Anigma.app
- **Purpose**: GUI application interface
- **Location**: `/Applications/Anigma.app`
- **Features**:
  - Native macOS app bundle
  - Status display and user interaction
  - Proper Info.plist configuration

### 3. Command-Line Tools
- **anigmad**: Direct access to daemon executable
- **anigma-cli**: CLI wrapper for daemon interaction
- **Location**: `/usr/local/bin/`

### 4. LaunchAgent
- **File**: `com.anigma.daemon.plist`
- **Location**: `~/Library/LaunchAgents/`
- **Behavior**:
  - Runs at user login
  - Automatic restart if crashed
  - Proper resource limits

## Installation

### Quick Install
```bash
sudo installer -pkg Anigma-1.0.0.pkg -target /
```

### GUI Install
1. Double-click `Anigma-1.0.0.pkg`
2. Follow installation wizard
3. Applications automatically configured

## Post-Installation

### Verification
```bash
# Check daemon status
launchctl list | grep com.anigma.daemon

# Check CLI tools
anigma-cli --help
anigmad --version

# Check logs
tail -f /tmp/com.anigma.daemon.log
```

## Uninstallation

### Automated Uninstall
```bash
/Applications/AnigmaDaemon.app/Contents/MacOS/uninstall
```

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (arm64) or Intel (x86_64)
- **Memory**: 100MB minimum
- **Storage**: 50MB disk space
- **Permissions**: Administrator access for installation
