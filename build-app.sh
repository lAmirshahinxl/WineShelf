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
logo_png="$project_dir/Assets/Branding/WineShelf-Logo.png"
build_temp="$(mktemp -d "${TMPDIR:-/tmp}/wineshelf-build.XXXXXX")"
trap 'rm -rf "$build_temp"' EXIT

if [[ ! "$app_version" =~ ^[0-9]+(\.[0-9]+){1,2}(-[A-Za-z0-9.]+)?$ ]]; then
    echo "APP_VERSION must be a dotted version such as 0.2.0 or 0.2.0-beta.1" >&2
    exit 1
fi

swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "$arm_scratch" --product WineShelf
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$x86_scratch" --product WineShelf

if [[ ! -f "$logo_png" ]]; then
    echo "App icon source not found: $logo_png" >&2
    exit 1
fi

rm -rf "$app_dir"
mkdir -p "$dist_dir" "$contents_dir/MacOS" "$contents_dir/Resources"
lipo -create \
    "$arm_scratch/release/WineShelf" \
    "$x86_scratch/release/WineShelf" \
    -output "$contents_dir/MacOS/WineShelf"

iconset_dir="$build_temp/AppIcon.iconset"
mkdir -p "$iconset_dir"
while IFS=' ' read -r filename pixels; do
    sips -z "$pixels" "$pixels" "$logo_png" --out "$iconset_dir/$filename" >/dev/null
done <<'ICON_SIZES'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
ICON_SIZES
iconutil -c icns "$iconset_dir" -o "$contents_dir/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

archive="$dist_dir/WineShelf-$app_version-universal.dmg"
legacy_archive="$dist_dir/WineShelf-$app_version-universal.zip"
dmg_root="$build_temp/dmg-root"
mkdir -p "$dmg_root"
ditto "$app_dir" "$dmg_root/WineShelf.app"
ln -s /Applications "$dmg_root/Applications"
rm -f "$archive" "$legacy_archive"
hdiutil create -volname "WineShelf $app_version" -srcfolder "$dmg_root" -ov -format UDZO "$archive" >/dev/null
echo "Built: $app_dir"
echo "Disk image: $archive"
echo "Architectures: $architectures"
echo "Signing identity: $signing_identity"
