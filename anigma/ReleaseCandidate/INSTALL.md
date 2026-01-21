# Anigma Installer - Quick Start Guide

## Installation

### Method 1: Using installer command (Recommended)

```bash
cd /Users/user/Developer/GitHub/Anigma/ReleaseCandidate
sudo installer -pkg AnigmaInstaller-1.0.0-rc20260108.pkg -target /
```

### Method 2: Double-click in Finder

1. Navigate to `/Users/user/Developer/GitHub/Anigma/ReleaseCandidate/`
2. Double-click `AnigmaInstaller-1.0.0-rc20260108.pkg`
3. Follow the installation wizard

## Post-Installation

### Verify Installation

```bash
# Check that binaries are in PATH
which harmonia
which anigmad
which ml-worker
which doctrine

# Verify versions
harmonia --help
anigmad --help
ml-worker --help
doctrine --help

# Check version info
cat /usr/local/bin/VERSION.txt
```

### Start Using Anigma

#### 1. Start the Daemon

```bash
# Start the background daemon
harmonia daemon start

# Check daemon status
harmonia daemon status
```

#### 2. Run Doctrine Analysis

```bash
# Analyze a Swift project
doctrine scan /path/to/your/project

# Check for contract violations
doctrine check /path/to/your/project
```

#### 3. Use ML Worker

```bash
# See available ML worker commands
ml-worker --help
```

## Uninstallation

To remove the installed binaries:

```bash
sudo rm /usr/local/bin/harmonia
sudo rm /usr/local/bin/anigmad
sudo rm /usr/local/bin/ml-worker
sudo rm /usr/local/bin/doctrine
sudo rm /usr/local/bin/VERSION.txt
```

Or use pkgutil:

```bash
# List installed packages
pkgutil --pkgs | grep anigma

# Forget the package (doesn't remove files, but removes receipt)
sudo pkgutil --forget com.anigma.installer

# Then remove files manually as shown above
```

## Troubleshooting

### Permission Denied Errors

If you get permission errors:

```bash
# Check file permissions
ls -la /usr/local/bin/harmonia

# Make executable if needed
sudo chmod +x /usr/local/bin/harmonia
sudo chmod +x /usr/local/bin/anigmad
sudo chmod +x /usr/local/bin/ml-worker
sudo chmod +x /usr/local/bin/doctrine
```

### Daemon Won't Start

```bash
# Check for existing daemon
ps aux | grep anigmad

# Stop any running daemon
harmonia daemon stop

# Start fresh
harmonia daemon start --foreground
```

### Binary Not Found

```bash
# Check PATH
echo $PATH

# Add /usr/local/bin to PATH if needed (add to ~/.zshrc or ~/.bashrc)
export PATH="/usr/local/bin:$PATH"
```

## System Requirements

- **macOS:** 14.0 (Sonoma) or later
- **Architecture:** Apple Silicon (arm64)
- **Disk Space:** ~300 MB for installation
- **Memory:** Minimum 4 GB RAM recommended

## Security

These binaries are **unsigned** and **not notarized**. macOS may prevent them from running.

To allow unsigned binaries:

```bash
# Remove quarantine attribute
sudo xattr -d com.apple.quarantine /usr/local/bin/harmonia
sudo xattr -d com.apple.quarantine /usr/local/bin/anigmad
sudo xattr -d com.apple.quarantine /usr/local/bin/ml-worker
sudo xattr -d com.apple.quarantine /usr/local/bin/doctrine
```

Or allow in System Settings:
1. System Settings → Privacy & Security
2. Scroll to "Security" section
3. Click "Allow" next to the blocked app message

## Verification

Verify package integrity using SHA256 checksums:

```bash
# Compare with SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
```

Expected checksum for package:
```
0e27157f56a3ae1205aa93d81fc2138c1096c686756a9332273c4dd53c69ac0f
```

## Support

For issues or questions:
- Check the README.md in this directory
- Review build logs: `build_release.log`
- Check package contents: `package_contents.txt`

---

**Version:** 1.0.0-rc20260106  
**Build Date:** 2026-01-07 07:46:07 UTC
