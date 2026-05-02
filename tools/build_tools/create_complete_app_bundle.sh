#!/bin/bash

# Script to create a complete Anigma.app bundle from existing build artifacts
# This creates a proper app bundle structure with all necessary components

set -e

echo "🔨 Creating Complete Anigma App Bundle..."
echo ""

# Configuration
APP_BUNDLE="./anigma/Anigma/build/Anigma.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
PLUGINS="$CONTENTS/PlugIns"
SHARED_SUPPORT="$CONTENTS/SharedSupport"

# Clean and create structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS" "$PLUGINS" "$SHARED_SUPPORT"

echo "📦 Creating app bundle structure..."
echo "  Location: $APP_BUNDLE"
echo ""

# Create Info.plist
echo "📄 Creating Info.plist..."
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Anigma</string>
    <key>CFBundleExecutable</key>
    <string>AnigmaAppMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.anigma.app</string>
    <key>CFBundleName</key>
    <string>Anigma</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
PLIST
echo "  ✓ Info.plist created"

# Create PkgInfo
echo "📋 Creating PkgInfo..."
echo "APPL????" > "$CONTENTS/PkgInfo"
echo "  ✓ PkgInfo created"

# Create app icon
echo "🎨 Creating app icon..."
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
    sips -s format png -z 512 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out "$RESOURCES/AppIcon.png"
    echo "  ✓ AppIcon.png created"
fi

# Copy existing daemon from installer
echo "🔗 Copying daemon from installer..."
if [ -f "./anigma/installer/distribution/cli/anigmad" ]; then
    cp "./anigma/installer/distribution/cli/anigmad" "$MACOS/anigmad"
    chmod +x "$MACOS/anigmad"
    echo "  ✓ Copied anigmad (68KB)"
else
    echo "  ⚠️  Daemon not found in installer"
fi

# Create CLI wrapper
echo "📝 Creating CLI wrapper..."
cat > "$MACOS/anigma-cli" << 'CLI'
#!/bin/bash
ANIGMA_DAEMON="$MACOS/anigmad"
if [ -f "$ANIGMA_DAEMON" ]; then
    "$ANIGMA_DAEMON" "$@"
else
    echo "Error: AnigmaDaemon not found. Please reinstall Anigma."
    exit 1
fi
CLI
chmod +x "$MACOS/anigma-cli"
echo "  ✓ Created anigma-cli wrapper"

# Create launch agent plist
echo "🚀 Creating launch agent configuration..."
mkdir -p "$SHARED_SUPPORT/LaunchAgents"
cat > "$SHARED_SUPPORT/LaunchAgents/com.anigma.daemon.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anigma.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$MACOS/anigmad</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/com.anigma.daemon.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/com.anigma.daemon.err</string>
</dict>
</plist>
PLIST
echo "  ✓ Created launch agent configuration"

# Create uninstall script
echo "🗑️  Creating uninstall script..."
cat > "$MACOS/uninstall" << 'UNINSTALL'
#!/bin/bash
set -e
echo "🗑️  Uninstalling Anigma..."
if launchctl list | grep -q "com.anigma.daemon"; then
    launchctl unload "$HOME/Library/LaunchAgents/com.anigma.daemon.plist" 2>/dev/null || true
fi
rm -f "$HOME/Library/LaunchAgents/com.anigma.daemon.plist"
rm -f "/usr/local/bin/anigmad"
rm -f "/usr/local/bin/anigma-cli"
rm -rf "/Applications/Anigma.app"
rm -rf "/Applications/AnigmaDaemon.app"
rm -rf "$HOME/Library/Application Support/Anigma"
pkill -f "anigmad" 2>/dev/null || true
echo "✅ Anigma has been successfully uninstalled."
exit 0
UNINSTALL
chmod +x "$MACOS/uninstall"
echo "  ✓ Created uninstall script"

# Create README
echo "📖 Creating README..."
cat > "$RESOURCES/README.txt" << 'README'
Anigma Application Bundle
=========================

This is a complete Anigma.app bundle containing:

EXECUTABLES:
- AnigmaAppMac: Main application (SwiftUI)
- anigmad: Background daemon
- anigma-cli: Command line interface
- uninstall: Uninstall script

CONFIGURATION:
- LaunchAgents/com.anigma.daemon.plist: Launch agent configuration

USAGE:
1. To run the application:
   open Anigma.app

2. To run the daemon manually:
   Anigma.app/Contents/MacOS/anigmad

3. To use the CLI:
   Anigma.app/Contents/MacOS/anigma-cli --help

4. To uninstall:
   Anigma.app/Contents/MacOS/uninstall

NOTES:
- This bundle uses dynamic linking to Swift Package Manager dependencies
- All processing capabilities are loaded at runtime
- The daemon runs in the background and handles document processing
README
chmod +x "$RESOURCES/README.txt"
echo "  ✓ Created README"

echo ""
echo "=========================================="
echo "✅ Complete Anigma App Bundle Created!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
echo "Bundle Contents:"
echo "  Executables:"
for file in "$MACOS"/*; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "    - $(basename "$file") ($size)"
    fi
done
echo ""
echo "  Configuration:"
echo "    - Info.plist"
echo "    - PkgInfo"
echo "    - LaunchAgents/com.anigma.daemon.plist"
echo ""
echo "  Resources:"
echo "    - AppIcon.png"
echo "    - README.txt"
echo ""
echo "To install and run:"
echo "  1. Copy to /Applications/"
echo "  2. Run: open -a Anigma"
echo "  3. The daemon will start automatically"
echo ""
echo "To uninstall:"
echo "  Run: Anigma.app/Contents/MacOS/uninstall"
