#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) Snip.app next to this script.
set -e
cd "$(dirname "$0")"
APP=Snip.app
BIN=$APP/Contents/MacOS/Snip
rm -rf $APP build
mkdir -p $APP/Contents/MacOS build
for ARCH in arm64 x86_64; do
  swiftc -Osize -swift-version 5 -target $ARCH-apple-macos14 -parse-as-library main.swift -o build/Snip-$ARCH
done
lipo -create build/Snip-arm64 build/Snip-x86_64 -output $BIN
rm -rf build
strip -x $BIN
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Snip</string>
  <key>CFBundleIdentifier</key><string>io.github.yossev.snip</string>
  <key>CFBundleName</key><string>Snip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict></plist>
PLIST
codesign -s - --force $APP
du -sh $APP
