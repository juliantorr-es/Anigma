#!/bin/bash

# Anigma macOS Installer Build Script
set -e

PROJECT_ROOT="$(pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
INSTALLER_DIR="${PROJECT_ROOT}/installer"
VERSION="1.0.0"

echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "🔨 Building applications..."
swift build -c release --product anigmad
if [ -f ".build/arm64-apple-macosx/release/anigmad" ]; then
    cp ".build/arm64-apple-macosx/release/anigmad" "${BUILD_DIR}/anigmad"
    echo "✅ AnigmaDaemon built successfully"
else
    echo "❌ AnigmaDaemon build failed"
    exit 1
fi

echo "📦 Creating AnigmaDaemon.app..."
mkdir -p "${BUILD_DIR}/AnigmaDaemon.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/AnigmaDaemon.app/Contents/Resources"

cat > "${BUILD_DIR}/AnigmaDaemon.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>AnigmaDaemon</string>
    <key>CFBundleExecutable</key>
    <string>anigmad</string>
    <key>CFBundleIdentifier</key>
    <string>com.anigma.daemon</string>
    <key>CFBundleName</key>
    <string>AnigmaDaemon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "${BUILD_DIR}/anigmad" "${BUILD_DIR}/AnigmaDaemon.app/Contents/MacOS/"

echo "⚙️ Creating LaunchAgent..."
mkdir -p "${BUILD_DIR}/LaunchAgents"

cat > "${BUILD_DIR}/LaunchAgents/com.anigma.daemon.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.anigma.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/AnigmaDaemon.app/Contents/MacOS/anigmad</string>
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
EOF

echo "🔧 Creating CLI tools..."
mkdir -p "${BUILD_DIR}/cli"

cat > "${BUILD_DIR}/cli/anigma-cli" << 'EOF'
#!/bin/bash
ANIGMA_DAEMON="/Applications/AnigmaDaemon.app/Contents/MacOS/anigmad"
if [ -f "$ANIGMA_DAEMON" ]; then
    "$ANIGMA_DAEMON" "$@"
else
    echo "Error: AnigmaDaemon not found. Please reinstall Anigma."
    exit 1
fi
EOF

chmod +x "${BUILD_DIR}/cli/anigma-cli"
ln -sf "/Applications/AnigmaDaemon.app/Contents/MacOS/anigmad" "${BUILD_DIR}/cli/anigmad"

echo "🖥️ Creating Anigma.app..."
mkdir -p "${BUILD_DIR}/Anigma.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/Anigma.app/Contents/Resources"

cat > "${BUILD_DIR}/Anigma.app/Contents/Info.plist" << 'EOF'
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
</dict>
</plist>
EOF

cat > "${BUILD_DIR}/Anigma.app/Contents/MacOS/AnigmaAppMac" << 'EOF'
#!/bin/bash
osascript -e 'display dialog "Anigma is now installed and running!\n\n• Daemon: Running in background\n• CLI: Available as anigma-cli\n• Status: Check /tmp/com.anigma.daemon.log" buttons {"OK"} default button "OK" with title "Anigma Status"'
EOF

chmod +x "${BUILD_DIR}/Anigma.app/Contents/MacOS/AnigmaAppMac"

cat > "${BUILD_DIR}/AnigmaDaemon.app/Contents/MacOS/uninstall" << 'EOF'
#!/bin/bash
set -e
echo "🗑️ Uninstalling Anigma..."
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
EOF

chmod +x "${BUILD_DIR}/AnigmaDaemon.app/Contents/MacOS/uninstall"

echo "📦 Creating distribution package..."
mkdir -p "${INSTALLER_DIR}/distribution"
cp -R "${BUILD_DIR}/Anigma.app" "${INSTALLER_DIR}/distribution/"
cp -R "${BUILD_DIR}/AnigmaDaemon.app" "${INSTALLER_DIR}/distribution/"
cp -R "${BUILD_DIR}/LaunchAgents" "${INSTALLER_DIR}/distribution/"
cp -R "${BUILD_DIR}/cli" "${INSTALLER_DIR}/distribution/"

echo "🏗️ Building installer package..."
pkgbuild \
    --root "${INSTALLER_DIR}/distribution" \
    --identifier com.anigma.installer \
    --version 1.0.0 \
    --install-location "/tmp/anigma_install" \
    --scripts "${INSTALLER_DIR}" \
    --ownership recommended \
    "${INSTALLER_DIR}/AnigmaInstaller.pkg"

productbuild \
    --distribution "${INSTALLER_DIR}/Distribution.xml" \
    --package-path "${INSTALLER_DIR}" \
    "${INSTALLER_DIR}/Anigma-${VERSION}.pkg"

rm -f "${INSTALLER_DIR}/AnigmaInstaller.pkg"

echo "✅ Installer created: ${INSTALLER_DIR}/Anigma-${VERSION}.pkg"
echo "🎉 Build completed!"
