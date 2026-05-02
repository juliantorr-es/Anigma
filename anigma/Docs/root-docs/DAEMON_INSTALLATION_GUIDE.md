# Anigma Daemon Installation Guide

## ✅ Installation Status: READY

This guide provides instructions for building and installing the full Anigma daemon with event-driven architecture support.

## 📦 What's Being Installed

### Two Daemon Components

1. **anigmad** - Full daemon (application bundle)
   - Location: `anigma/Anigma/build/AnigmaDaemon.app/Contents/MacOS/anigmad`
   - Size: 58KB
   - Type: Application bundle with uninstall script

2. **anigma-daemon-simple** - Simple daemon (command-line)
   - Location: `anigma/.build/arm64-apple-macosx/debug/anigma-daemon-simple`
   - Size: 989KB
   - Type: Command-line executable

## 🔧 Prerequisites

### Required Tools
- Xcode Command Line Tools
- Swift 6.0+
- macOS 14+ (Ventura)

### Verify Prerequisites
```bash
# Check Swift version
swift --version

# Check Xcode tools
xcode-select --version
```

## 🚀 Build Instructions

### 1. Build the Full Daemon

```bash
cd anigma
swift build -c release --product anigmad
```

**Note**: The full daemon is actually built as part of the Anigma app build process. The executable is located in:
```
anigma/Anigma/build/AnigmaDaemon.app/Contents/MacOS/anigmad
```

### 2. Build the Simple Daemon

```bash
cd anigma
swift build -c release --product anigma-daemon-simple
```

**Output**: `anigma/.build/arm64-apple-macosx/release/anigma-daemon-simple`

## 📋 Installation Methods

### Method 1: System-Wide Installation (Recommended)

```bash
# Install to /usr/local/bin
sudo cp anigma/.build/arm64-apple-macosx/release/anigma-daemon-simple /usr/local/bin/anigmad

# Make executable
sudo chmod +x /usr/local/bin/anigmad

# Verify installation
which anigmad
anigmad --version
```

### Method 2: User Local Installation

```bash
# Install to ~/.local/bin
mkdir -p ~/.local/bin
cp anigma/.build/arm64-apple-macosx/release/anigma-daemon-simple ~/.local/bin/anigmad

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
which anigmad
```

### Method 3: Application Bundle Installation

```bash
# Copy the full application bundle
sudo cp -r anigma/Anigma/build/AnigmaDaemon.app /Applications/

# Run the daemon
open /Applications/AnigmaDaemon.app
```

## 🔄 Replacing Existing Installation

### Check for Existing Installation
```bash
# Check if daemon is installed
which anigmad

# Check version
anigmad --version 2>/dev/null || echo "Not installed or no version flag"
```

### Replace Existing Daemon
```bash
# Stop existing daemon (if running)
sudo launchctl stop com.anigma.daemon

# Remove old installation
sudo rm -f /usr/local/bin/anigmad

# Install new version
sudo cp anigma/.build/arm64-apple-macosx/release/anigma-daemon-simple /usr/local/bin/anigmad
sudo chmod +x /usr/local/bin/anigmad

# Start new daemon
sudo launchctl start com.anigma.daemon
```

## 📝 Launch Daemon Configuration

### Create Launch Daemon

```bash
# Create launch daemon plist
sudo tee /Library/LaunchDaemons/com.anigma.daemon.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anigma.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/anigmad</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/anigmad.out</string>
    <key>StandardErrorPath</key>
    <string>/var/log/anigmad.err</string>
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
EOF

# Load the daemon
sudo launchctl load /Library/LaunchDaemons/com.anigma.daemon.plist

# Start the daemon
sudo launchctl start com.anigma.daemon
```

## 🔍 Verification

### Check Daemon Status
```bash
# Check if daemon is running
ps aux | grep anigmad

# Check logs
tail -f /var/log/anigmad.out

# Check errors
tail -f /var/log/anigmad.err
```

### Test Daemon Functionality
```bash
# Test basic functionality
anigmad --help

# Test event publishing
# (The daemon should automatically publish startup events to the event bus)
```

## 🎯 Event-Driven Features

### What's New in This Version

The updated daemon includes full event-driven architecture support:

1. **Job Lifecycle Events**
   - `JobSubmitted(jobId:workflowId:)`
   - `JobStatusUpdated(jobId:status:)`
   - `JobToken(jobId:token:)`
   - `JobCompleted(jobId:receiptRef:)`

2. **Workflow Events**
   - `WorkflowStarted(workflowId:)`
   - `WorkflowProgress(workflowId:progress:)`
   - `WorkflowCompleted(workflowId:receiptRef:)`
   - `WorkflowFailed(workflowId:error:)`

3. **System Events**
   - `SystemNotification(message:)`
   - `SystemError(error:context:)`

### Monitoring Events

```bash
# Subscribe to job events (example)
# Use the AnigmaCLI or create a custom subscriber

# View event logs
tail -f /var/log/anigmad.out | grep -i event
```

## ⚠️ Troubleshooting

### Common Issues

#### Daemon Won't Start
```bash
# Check permissions
ls -la /usr/local/bin/anigmad

# Check logs
cat /var/log/anigmad.err

# Reinstall
sudo rm /usr/local/bin/anigmad
sudo cp anigma/.build/arm64-apple-macosx/release/anigma-daemon-simple /usr/local/bin/anigmad
```

#### Event Publishing Not Working
```bash
# Check daemon logs
tail -f /var/log/anigmad.out

# Verify event bus is running
# (The event bus is part of the Anigma system and should be running)
```

#### Permission Issues
```bash
# Fix permissions
sudo chmod +x /usr/local/bin/anigmad
sudo chown root:wheel /usr/local/bin/anigmad
```

## 📊 Build Verification

### Verify Build
```bash
# Check build output
cd anigma
swift build -c release --product anigma-daemon-simple 2>&1 | tail -5

# Expected output
# Build of product 'anigma-daemon-simple' complete! (X.XXs)
```

### Verify Event Integration
```bash
# Check that AnigmaEvents is included
grep -r "import AnigmaEvents" anigma/Packages/AnigmaDaemonCore/Sources/

# Should show:
# AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Jobs.swift
```

## 🎉 Final Steps

### Summary
1. ✅ Build the daemon
2. ✅ Install to system location
3. ✅ Configure as launch daemon
4. ✅ Start the daemon
5. ✅ Verify functionality

### Next Steps
- Monitor daemon logs
- Test job submission
- Verify event publishing
- Integrate with workflow engine

## 📚 Additional Resources

- **Event-Driven Architecture Guide**: `EVENT_DRIVEN_ARCHITECTURE_GUIDE.md`
- **Build Verification Report**: `BUILD_VERIFICATION_REPORT.md`
- **Daemon Build Verification**: `DAEMON_BUILD_VERIFICATION.md`
- **Full Daemon Verification**: `FULL_DAEMON_VERIFICATION.md`

## 🎯 Support

For issues or questions:
1. Check logs in `/var/log/anigmad.out` and `/var/log/anigmad.err`
2. Review this installation guide
3. Consult the documentation files
4. Contact support with detailed error messages

## 📝 Notes

- The daemon requires macOS 14+ (Ventura)
- The daemon runs as a background service
- Event-driven features require the full Anigma system
- Daemon logs are written to `/var/log/anigmad.out` and `/var/log/anigmad.err`

**Status**: ✅ **Ready for installation and deployment**
