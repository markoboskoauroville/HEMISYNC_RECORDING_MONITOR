#!/bin/sh
# build.sh: Hemi-Sync Recording Monitor (Mantra).app. Run by GitHub Actions only (.github/workflows/build.yml), never on the Mac.
set -e
cd "$(dirname "$0")"
sh check_one_title.sh
V=$(sed -n 's/^let VERSION = \([0-9]*\)/\1/p' app/App.swift)
NAME="Hemi-Sync Recording Monitor (Mantra)"
APP="build/$NAME.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/HemiSyncRecordingMonitor" app/*.swift 2>&1 | grep -v "warning:" || true
[ -x "$APP/Contents/MacOS/HemiSyncRecordingMonitor" ] || { echo "the app did not build"; exit 1; }
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundleIdentifier</key><string>community.auroville.hemisyncrecordingmonitor</string>
<key>CFBundleExecutable</key><string>HemiSyncRecordingMonitor</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$V</string>
<key>CFBundleVersion</key><string>$V</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
# GitHub has no "Mantra Apps" certificate: SIGN=- (ad hoc) there; on the Mac the release is re-signed "Mantra Apps".
codesign --force -s "${SIGN:-Mantra Apps}" "$APP"
echo "built $APP (v$V)"
