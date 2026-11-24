#!/bin/bash
# Build LyricWall 1.0.0 IPA on Linux with the Theos toolchain (clang + ldid).
# Local work only: no push, no deploy.
set -e
PROJ=~/workspace/lyricwall-ipa
SDK=$HOME/theos/sdks/iPhoneOS16.5.sdk
TC=$HOME/theos/toolchain/linux/iphone/bin
BUILD=$PROJ/build
APP=$BUILD/Payload/LyricWall.app
IPA=$PROJ/LyricWall-1.0.0.ipa

rm -rf "$BUILD" "$IPA"
mkdir -p "$APP"

echo "== compile =="
"$TC/clang" -target arm64-apple-ios15.0 -isysroot "$SDK" -miphoneos-version-min=15.0 \
  -arch arm64 -fobjc-arc -O2 \
  -framework Foundation -framework UIKit -framework WebKit -framework CoreGraphics \
  -o "$APP/LyricWall" "$PROJ/src/main.m" "$PROJ/src/AppDelegate.m" "$PROJ/src/ViewController.m" \
  "$PROJ/src/ActivationManager.m" "$PROJ/src/ActivationViewController.m"

echo "== assemble =="
cp "$PROJ/Info.plist" "$APP/Info.plist"
cp -r "$PROJ/lyricwall" "$APP/lyricwall"
mkdir -p "$APP/license"
cp "$PROJ/license/codes-lyricwall.json" "$APP/license/codes-lyricwall.json"
cp "$PROJ"/icons/*.png "$APP/"
cp "$PROJ"/launch/*.png "$APP/"
chmod 0755 "$APP/LyricWall"
"$TC/strip" "$APP/LyricWall" || true

echo "== fake-sign (TrollStore) =="
# ldid can't sign in place under ~/workspace (Operation not permitted on that
# mount), so sign a /tmp copy and copy it back.
cp "$APP/LyricWall" /tmp/LyricWall.sign
"$TC/ldid" -S /tmp/LyricWall.sign
cp /tmp/LyricWall.sign "$APP/LyricWall"
chmod 0755 "$APP/LyricWall"
rm -f /tmp/LyricWall.sign

echo "== zip =="
cd "$BUILD"
zip -r -y -q "$IPA" Payload
ls -la "$IPA"
sha256sum "$IPA"
echo "BUILD OK: $IPA"
