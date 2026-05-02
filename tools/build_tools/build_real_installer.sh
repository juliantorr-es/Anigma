#!/bin/bash

# Real Binary Build and Installer Creation Script
# Uses Xcode/SwiftPM for real binaries, no placeholders

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/enable_sccache.sh"
enable_sccache


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Anigma Real Binary Installer ===${NC}"
echo "Building real binaries, no placeholders"
echo ""

# Config
PROJECT_ROOT="anigma"
BUILD_DIR="${PROJECT_ROOT}/.build"
INSTALLER_DIR="installer"
PACKAGE_DIR="install_package"
DIST_DIR="${INSTALLER_DIR}/dist"
PRODUCT_NAME="Anigma"
VERSION="3.0.0"

mkdir -p "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

status() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    error "Xcode not found. Install: xcode-select --install"
fi

echo -e "${BLUE}=== Cleaning ===${NC}"
rm -rf "${BUILD_DIR}/DerivedData"
rm -f "${PACKAGE_DIR}/usr/local/bin/anigma-cli"
rm -f "${PACKAGE_DIR}/usr/local/bin/anigmad"
rm -f "${PACKAGE_DIR}/Applications/Anigma Status Bar.app/Contents/MacOS/anigma-status-bar"

echo -e "${BLUE}=== Building Binaries ===${NC}"

# Build CLI
echo -e "${BLUE}Building CLI...${NC}"
CLI_PACKAGE="${PROJECT_ROOT}/Packages/AnigmaCLI"
if [ -d "$CLI_PACKAGE" ]; then
    cd "$CLI_PACKAGE"
    swift build --configuration release
    CLI_BIN=$(find .build -name "anigma-cli" -type f | head -1)
    if [ -n "$CLI_BIN" ]; then
        cp "$CLI_BIN" "../../${PACKAGE_DIR}/usr/local/bin/anigma-cli"
        chmod +x "../../${PACKAGE_DIR}/usr/local/bin/anigma-cli"
        status "CLI built: $(basename "$CLI_BIN") ($(stat -f%z "$CLI_BIN" | numfmt --to=iec))"
    else
        error "CLI binary not found"
    fi
    cd ../..
else
    error "CLI package not found"
fi

# Build Daemon
echo -e "${BLUE}Building Daemon...${NC}"
DAEMON_PACKAGE="${PROJECT_ROOT}/Packages/AnigmaDaemon"
if [ -d "$DAEMON_PACKAGE" ]; then
    cd "$DAEMON_PACKAGE"
    swift build --configuration release
    DAEMON_BIN=$(find .build -name "anigmad" -type f | head -1)
    if [ -n "$DAEMON_BIN" ]; then
        cp "$DAEMON_BIN" "../../${PACKAGE_DIR}/usr/local/bin/anigmad"
        chmod +x "../../${PACKAGE_DIR}/usr/local/bin/anigmad"
        status "Daemon built: $(basename "$DAEMON_BIN") ($(stat -f%z "$DAEMON_BIN" | numfmt --to=iec))"
    else
        warning "Daemon binary not found, using existing"
    fi
    cd ../..
else
    warning "Daemon package not found, using existing binary"
fi

# Build Status Bar App
echo -e "${BLUE}Building Status Bar App...${NC}"
APP_DIR="${PACKAGE_DIR}/Applications/Anigma Status Bar.app"
if [ -d "$APP_DIR" ]; then
    # Check for StatusBar package
    STATUSBAR_PACKAGE=$(find "${PROJECT_ROOT}" -path "*StatusBar*" -type d | head -1)
    if [ -d "$STATUSBAR_PACKAGE" ]; then
        cd "$STATUSBAR_PACKAGE"
        swift build --configuration release
        APP_BIN=$(find .build -name "anigma-status-bar" -type f | head -1)
        if [ -n "$APP_BIN" ]; then
            cp "$APP_BIN" "../../${APP_DIR}/Contents/MacOS/anigma-status-bar"
            chmod +x "../../${APP_DIR}/Contents/MacOS/anigma-status-bar"
            status "Status Bar built: $(basename "$APP_BIN") ($(stat -f%z "$APP_BIN" | numfmt --to=iec))"
        else
            warning "Status Bar binary not found"
        fi
        cd ../..
    else
        warning "Status Bar package not found"
    fi
else
    warning "Status Bar app directory not found"
fi

echo -e "${BLUE}=== Creating Installers ===${NC}"

# Create DMG
echo -e "${BLUE}Creating DMG installer...${NC}"
DMG_NAME="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}.dmg"
DMG_TEMP="${BUILD_DIR}/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "${PACKAGE_DIR}/Applications/Anigma Status Bar.app" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"
hdiutil create \
    -volname "${PRODUCT_NAME} Installer" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_NAME"
status "DMG created: $(basename "$DMG_NAME") ($(stat -f%z "$DMG_NAME" | numfmt --to=iec))"

# Create PKG if distribution file exists
if [ -f "${INSTALLER_DIR}/resources/Distribution" ]; then
    echo -e "${BLUE}Creating PKG installer...${NC}"
    # Fix XML
    sed -i '' 's/&/&amp;/g' "${INSTALLER_DIR}/resources/Distribution"
    
    COMPONENT_PKG="${DIST_DIR}/${PRODUCT_NAME}.pkg"
    pkgbuild \
        --root "$PACKAGE_DIR" \
        --identifier "com.anigma.cli-daemon" \
        --version "$VERSION" \
        --install-location "/" \
        "$COMPONENT_PKG"
    
    if [ $? -eq 0 ]; then
        DIST_PKG="${DIST_DIR}/${PRODUCT_NAME}-Installer.pkg"
        productbuild \
            --distribution "${INSTALLER_DIR}/resources/Distribution" \
            --resources "${INSTALLER_DIR}/resources" \
            --package-path "$(dirname "$COMPONENT_PKG")" \
            "$DIST_PKG"
        status "PKG created: $(basename "$DIST_PKG") ($(stat -f%z "$DIST_PKG" | numfmt --to=iec))"
    fi
fi

# Create archive
echo -e "${BLUE}Creating archive...${NC}"
ARCHIVE_NAME="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}.tar.gz"
tar -czf "$ARCHIVE_NAME" -C "$PACKAGE_DIR" .
status "Archive created: $(basename "$ARCHIVE_NAME") ($(stat -f%z "$ARCHIVE_NAME" | numfmt --to=iec))"

echo -e "${BLUE}=== Verification ===${NC}"
echo -e "${GREEN}Built binaries:${NC}"
[ -f "${PACKAGE_DIR}/usr/local/bin/anigma-cli" ] && \
    echo "  • CLI: $(file "${PACKAGE_DIR}/usr/local/bin/anigma-cli" | cut -d: -f2-)"
[ -f "${PACKAGE_DIR}/usr/local/bin/anigmad" ] && \
    echo "  • Daemon: $(file "${PACKAGE_DIR}/usr/local/bin/anigmad" | cut -d: -f2-)"
[ -f "${APP_DIR}/Contents/MacOS/anigma-status-bar" ] && \
    echo "  • Status Bar: $(file "${APP_DIR}/Contents/MacOS/anigma-status-bar" | cut -d: -f2-)"

echo ""
echo -e "${BLUE}=== Complete ===${NC}"
echo -e "${GREEN}Installers in ${DIST_DIR}:${NC}"
ls -lh "$DIST_DIR" | grep -E "\.(dmg|pkg|tar\.gz)$" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo -e "${YELLOW}Total size:${NC} $(du -sh "$PACKAGE_DIR" | cut -f1)"
echo ""
echo -e "${GREEN}Run:${NC} ./install_package/install.sh"
echo -e "${GREEN}Or mount:${NC} ${DIST_DIR}/${PRODUCT_NAME}-${VERSION}.dmg"