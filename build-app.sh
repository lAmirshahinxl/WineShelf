#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"

swift build -c release --product WineShelf

app_dir="$project_dir/dist/WineShelf.app"
contents_dir="$app_dir/Contents"
mkdir -p "$contents_dir/MacOS"
cp "$project_dir/.build/release/WineShelf" "$contents_dir/MacOS/WineShelf"

cat > "$contents_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WineShelf</string>
    <key>CFBundleIdentifier</key>
    <string>local.wineshelf.app</string>
    <key>CFBundleName</key>
    <string>WineShelf</string>
    <key>CFBundleDisplayName</key>
    <string>WineShelf</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$app_dir"
echo "Built: $app_dir"
