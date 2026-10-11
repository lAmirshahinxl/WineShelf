#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"

app_version="${APP_VERSION:-0.2.0}"
short_version="${app_version%%-*}"
build_number="${BUILD_NUMBER:-1}"
signing_identity="${CODESIGN_IDENTITY:--}"
arm_scratch="$project_dir/.build-arm64"
x86_scratch="$project_dir/.build-x86_64"
dist_dir="$project_dir/dist"
app_dir="$dist_dir/WineShelf.app"
contents_dir="$app_dir/Contents"

if [[ ! "$app_version" =~ ^[0-9]+(\.[0-9]+){1,2}(-[A-Za-z0-9.]+)?$ ]]; then
    echo "APP_VERSION must be a dotted version such as 0.2.0 or 0.2.0-beta.1" >&2
    exit 1
fi

swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "$arm_scratch" --product WineShelf
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$x86_scratch" --product WineShelf

mkdir -p "$dist_dir" "$contents_dir/MacOS"
lipo -create \
    "$arm_scratch/release/WineShelf" \
    "$x86_scratch/release/WineShelf" \
    -output "$contents_dir/MacOS/WineShelf"

cat > "$contents_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WineShelf</string>
    <key>CFBundleIdentifier</key>
    <string>com.amirshahin.wineshelf</string>
    <key>CFBundleName</key>
    <string>WineShelf</string>
    <key>CFBundleDisplayName</key>
    <string>WineShelf</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>$build_number</string>
    <key>CFBundleShortVersionString</key>
    <string>$short_version</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

if [[ "$signing_identity" == "-" ]]; then
    codesign --force --deep --sign - "$app_dir"
else
    codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
architectures="$(lipo -archs "$contents_dir/MacOS/WineShelf")"
if [[ "$architectures" != *arm64* || "$architectures" != *x86_64* ]]; then
    echo "Expected a universal arm64+x86_64 executable, found: $architectures" >&2
    exit 1
fi

archive="$dist_dir/WineShelf-$app_version-universal.zip"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
echo "Built: $app_dir"
echo "Archive: $archive"
echo "Architectures: $architectures"
echo "Signing identity: $signing_identity"
