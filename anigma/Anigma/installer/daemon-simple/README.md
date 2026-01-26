# AnigmaDaemonSimple Installer

A simple, one-command installer for the AnigmaDaemonSimple background service.

## Overview

This installer provides a complete solution for building, installing, and configuring the AnigmaDaemonSimple daemon on macOS. The daemon runs as a background service with automatic startup on login, providing a REST API for Anigma applications.

## Features

- ✅ **Simple Installation**: One-command setup
- ✅ **Automatic Startup**: Runs via macOS LaunchAgent
- ✅ **Secure**: Auto-generates API keys for authentication
- ✅ **Configurable**: JSON-based configuration
- ✅ **Logging**: Comprehensive log management
- ✅ **Easy Management**: Start/stop/restart commands
- ✅ **Clean Uninstall**: Complete removal script

## Quick Start

### Option 1: One-Command Install (Recommended)
```bash
cd installer/daemon-simple
./one_command_install.sh
```

### Option 2: Manual Installation
```bash
cd installer/daemon-simple

# 1. Build the daemon
./build_daemon.sh

# 2. Install (user-local, no sudo needed)
./install.sh

# 3. Generate API key
./generate_api_key.sh

# 4. Test installation
./test_installation.sh
```

### Option 3: System-Wide Installation (with sudo)
```bash
cd installer/daemon-simple
sudo ./install.sh
```

## File Structure

```
installer/daemon-simple/
├── build_daemon.sh      # Builds daemon from source
├── install.sh           # Installation script
├── uninstall.sh         # Complete uninstallation
├── generate_api_key.sh  # Creates secure API key
├── test_installation.sh # Verifies installation
├── one_command_install.sh # All-in-one installer
└── README.md           # This file
```

## Installation Locations

| Component | User Installation | System Installation |
|-----------|-------------------|---------------------|
| Daemon Binary | `~/.local/bin/anigmad` | `/usr/local/bin/anigmad` |
| Configuration | `~/Library/Application Support/AnigmaDaemon/` | `~/Library/Application Support/AnigmaDaemon/` |
| LaunchAgent | `~/Library/LaunchAgents/com.anigma.daemon.plist` | `~/Library/LaunchAgents/com.anigma.daemon.plist` |
| Logs | `~/Library/Logs/AnigmaDaemon/` | `~/Library/Logs/AnigmaDaemon/` |

## Configuration

After installation, configure the daemon by editing:
```
~/Library/Application Support/AnigmaDaemon/config.json
```

### Default Configuration:
```json
{
    "api_key": "your-generated-api-key",
    "server_port": 8080,
    "log_level": "info",
    "auto_start": true
}
```

### Available Options:
- `server_port`: HTTP port for API (default: 8080)
- `log_level`: Logging level (debug, info, warning, error)
- `auto_start`: Auto-start on login (true/false)
- `api_key`: Authentication key (auto-generated)

## API Usage

The daemon provides a REST API on `http://localhost:8080` (port configurable).

### Endpoints:
- `GET /health` - Health check (returns "ok")
- `GET /status` - Daemon status and metrics
- `GET /metrics` - System metrics only
- `GET /config` - Current configuration
- `POST /config` - Update configuration (requires API key)

### Authentication:
All endpoints except `/health` require API key authentication:
```bash
curl -H "X-API-Key: YOUR_API_KEY" http://localhost:8080/status
```

## Management Commands

### Check Status
```bash
# Check if daemon is running
launchctl list | grep com.anigma.daemon

# View logs
tail -f ~/Library/Logs/AnigmaDaemon/daemon.log
```

### Start/Stop/Restart
```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.anigma.daemon.plist

# Start daemon
launchctl load ~/Library/LaunchAgents/com.anigma.daemon.plist

# Restart daemon
launchctl unload ~/Library/LaunchAgents/com.anigma.daemon.plist && launchctl load ~/Library/LaunchAgents/com.anigma.daemon.plist
```

### Manual Execution
```bash
# Run daemon manually (for debugging)
anigmad --config ~/Library/Application\ Support/AnigmaDaemon/config.json
```

## Uninstallation

### Complete Uninstall
```bash
./uninstall.sh
```

This will:
1. Stop the daemon
2. Remove LaunchAgent
3. Remove binary from all locations
4. Optionally remove configuration and logs
5. Clean up PATH modifications

### Partial Uninstall (keep config)
Run `./uninstall.sh` and choose "No" when asked about removing configuration.

## Troubleshooting

### Daemon Not Starting
1. Check logs: `tail -f ~/Library/Logs/AnigmaDaemon/daemon.err`
2. Verify binary exists: `which anigmad`
3. Check LaunchAgent: `launchctl list | grep anigma`

### API Not Responding
1. Ensure daemon is running: `launchctl list | grep anigma`
2. Check port: `lsof -i :8080`
3. Verify API key is set in config

### Permission Issues
If you get permission errors, try:
```bash
# For user installation
chmod +x ~/.local/bin/anigmad

# For system installation
sudo chmod +x /usr/local/bin/anigmad
```

## Backward Compatibility

This installer is designed to work alongside existing Anigma installations:
- Uses different LaunchAgent name (`com.anigma.daemon.plist`)
- Separate configuration directory (`AnigmaDaemon` vs `Anigma`)
- Can coexist with existing `anigmad` installations

To migrate from an existing installation:
1. Stop existing daemon
2. Install new daemon
3. Copy configuration if needed
4. Update clients to use new API key

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Swift**: 6.0 or later
- **Xcode Command Line Tools**: Required for building
- **Disk Space**: ~50MB for installation
- **Memory**: ~100MB for daemon operation

## Security Notes

1. **API Keys**: Generated automatically, stored in user's home directory
2. **Network Binding**: Defaults to localhost (127.0.0.1) only
3. **File Permissions**: Configuration and logs are user-readable only
4. **No Root Required**: User installation doesn't require sudo

## Development

### Building from Source
The daemon source is at `Sources/anigmad/main.swift`. To modify and rebuild:

```bash
# Rebuild daemon
cd /path/to/anigma/Anigma
swift build --product anigmad

# Re-run installer
cd installer/daemon-simple
./build_daemon.sh
./install.sh
```

### Testing Changes
```bash
# Run test suite
./test_installation.sh

# Manual testing
anigmad --test
curl http://localhost:8080/health
```

## Support

For issues or questions:
1. Check logs in `~/Library/Logs/AnigmaDaemon/`
2. Review configuration in `~/Library/Application Support/AnigmaDaemon/`
3. Run diagnostic test: `./test_installation.sh`

## License

Part of the Anigma project. See main project LICENSE for details.
