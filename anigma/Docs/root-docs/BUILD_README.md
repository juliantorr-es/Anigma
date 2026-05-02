# Anigma Build Scripts

This directory contains build scripts for compiling the Anigma project with optimized settings.

## Available Scripts

### `./build.sh` - Main build script
The most flexible script that supports multiple build methods.

**Usage:**
```bash
./build.sh [method] [target]
```

**Examples:**
```bash
# Default: xcodebuild with AnigmaAppMacExecutable
./build.sh

# Swift Package Manager build
./build.sh swift

# Build specific target with xcodebuild
./build.sh xcodebuild AnigmaCLI

# Build specific target with Swift Package Manager
./build.sh swift AnigmaDaemon
```

**Features:**
- Supports both `xcodebuild` and Swift Package Manager
- Uses 8 threads for parallel compilation
- Release configuration by default
- Clean build artifacts automatically
- Logs output to files
- Finds and displays executable information
- Optional run after build

### `./build-release.sh` - xcodebuild specific script
Optimized for Xcode builds with detailed logging.

**Usage:**
```bash
./build-release.sh [scheme]
```

### `./build-swift.sh` - Swift Package Manager specific script
Optimized for direct Swift builds.

**Usage:**
```bash
./build-swift.sh [target]
```

## Build Configuration

All scripts use the following optimized settings:
- **Threads**: 8 parallel jobs
- **Configuration**: Release/Release
- **Clean build**: Removes previous artifacts
- **Logging**: Output saved to log files
- **Error handling**: Detailed error reporting

## Common Targets/Schemes

- `AnigmaAppMacExecutable` - Main macOS application (default)
- `AnigmaCLI` - Command-line interface
- `AnigmaDaemon` - Background daemon
- `HarmoniaModule` - Core module
- `ObservatoriumModule` - Monitoring module

## Troubleshooting

### "multiple producers" build errors
If you encounter "multiple producers" errors:
1. Run a clean build: `rm -rf anigma/.build`
2. Use the Swift Package Manager method: `./build.sh swift`
3. Reduce thread count in the script if needed

### Missing Xcode project
The `xcodebuild` method requires an Xcode project. If missing:
1. The script will attempt to generate one automatically
2. Or use the Swift Package Manager method instead

### Module not found errors
If you see "No such module" errors:
1. Ensure all package dependencies are resolved: `cd anigma && swift package resolve`
2. Check the Package.swift for correct target dependencies
3. Try a clean build

## Performance Tips

1. **Use Release configuration** for production builds
2. **8 threads** is optimal for most modern Macs
3. **Clean builds** when changing dependencies
4. **Check logs** for optimization opportunities

## Quick Start

```bash
# Make scripts executable (first time only)
chmod +x build*.sh

# Build main application with default settings
./build.sh

# Or use Swift Package Manager directly
./build.sh swift
```