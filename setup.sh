#!/bin/bash
# ScreenAgent - Setup and Build Script
# Requires: Xcode 15+, macOS 13+, XcodeGen (optional)
set -e

echo "=== ScreenAgent Build Setup ==="

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# ----- Option A: Use XcodeGen (recommended) -----
if command -v xcodegen &>/dev/null; then
    echo "[1/3] Generating Xcode project with XcodeGen..."
    xcodegen generate
    echo "  ✓ ScreenAgent.xcodeproj created"
else
    echo "[1/3] XcodeGen not found. Install with: brew install xcodegen"
    echo "  Alternatively, create the Xcode project manually (see README)."
    echo ""
    echo "  To install XcodeGen and re-run:"
    echo "    brew install xcodegen"
    echo "    ./setup.sh"
    echo ""

    # ----- Option B: Create project manually -----
    echo "  Creating Xcode project manually with swift package..."

    # We'll generate a minimal xcodeproj using xcodebuild if possible
    if [ ! -d "ScreenAgent.xcodeproj" ]; then
        echo "  Please create the Xcode project manually:"
        echo "  1. Open Xcode → File → New → Project → macOS → App"
        echo "  2. Product Name: ScreenAgent, Interface: SwiftUI, Language: Swift"
        echo "  3. Uncheck 'Use Core Data', Uncheck 'Include Tests'"
        echo "  4. Save in this directory"
        echo "  5. Delete the auto-generated ContentView.swift"
        echo "  6. Drag all files from ScreenAgent/ folder into the Xcode project"
        echo "  7. Set Code Sign Identity to 'Sign to Run Locally' (or '-')"
        echo "  8. Set Deployment Target to macOS 13.0"
        echo "  9. Disable App Sandbox in Signing & Capabilities"
        echo "  10. Add ScreenAgent.entitlements in Build Settings"
        echo ""
        exit 1
    fi
fi

# ----- Build -----
echo "[2/3] Building ScreenAgent..."
xcodebuild \
    -project ScreenAgent.xcodeproj \
    -scheme ScreenAgent \
    -configuration Debug \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=YES \
    build 2>&1 | tail -20

BUILD_DIR="build/Build/Products/Debug"
if [ -d "$BUILD_DIR/ScreenAgent.app" ]; then
    echo "  ✓ Build successful"
    echo ""
    echo "[3/3] Run the app:"
    echo "  open $BUILD_DIR/ScreenAgent.app"
    echo ""
    echo "  Or run from terminal:"
    echo "  $BUILD_DIR/ScreenAgent.app/Contents/MacOS/ScreenAgent"
else
    echo "  ✗ Build failed. Check errors above."
    exit 1
fi

echo ""
echo "=== First Run Notes ==="
echo "1. macOS will prompt for Screen Recording permission → Allow it"
echo "2. Optionally grant Accessibility permission for enhanced text extraction"
echo "3. Toggle 'Screen Capture' ON in the dashboard to start"
echo "4. Events appear in the Search tab"
echo ""
echo "=== Done ==="
