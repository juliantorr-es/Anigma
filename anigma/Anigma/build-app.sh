#!/bin/bash

# Build script for Anigma macOS app bundle

set -e

echo "🔨 Building Anigma SwiftUI app..."
swift build --product AnigmaAppMac

echo "📦 Creating app bundle..."
mkdir -p build/Anigma.app/Contents/{MacOS,Resources}

echo "📋 Copying executable..."
cp .build/debug/AnigmaAppMac build/Anigma.app/Contents/MacOS/
chmod +x build/Anigma.app/Contents/MacOS/AnigmaAppMac

echo "📄 Creating Info.plist..."
cat > build/Anigma.app/Contents/Info.plist << 'PLIST'
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

echo "🎨 Creating app icon..."
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
    sips -s format png -z 512 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out build/Anigma.app/Contents/Resources/AppIcon.png
fi

echo "✅ App bundle created successfully!"
echo "🚀 Launch with: open build/Anigma.app"
