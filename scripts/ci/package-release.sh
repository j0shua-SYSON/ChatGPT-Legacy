#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/.derived-data/device"
STAGE="$ROOT/.artifacts/package-stage"
RELEASE="$ROOT/.artifacts/release"
rm -rf "$DERIVED" "$STAGE"
mkdir -p "$STAGE/Payload" "$RELEASE" .artifacts/logs

set -o pipefail
xcodebuild \
  -project ChatGPTLegacy.xcodeproj \
  -scheme ChatGPTLegacy \
  -configuration Release \
  -destination generic/platform=iOS \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build | tee .artifacts/logs/device-release-build.log

APP=""
for candidate in "$DERIVED/Build/Products/Release-iphoneos/"*.app; do
  if [[ -d "$candidate" ]]; then
    APP="$candidate"
    break
  fi
done
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Release app bundle not found." >&2
  exit 1
fi

/usr/bin/codesign --force --sign - --timestamp=none "$APP"
/usr/bin/codesign --verify --strict --verbose=2 "$APP" \
  2>&1 | tee .artifacts/logs/codesign-verify.log
ditto "$APP" "$STAGE/Payload/$(basename "$APP")"

IPA="$RELEASE/ChatGPT-Legacy-v${VERSION}-adhoc.ipa"
(cd "$STAGE" && /usr/bin/zip -qry "$IPA" Payload)
unzip -t "$IPA" | tee .artifacts/logs/ipa-integrity.log
unzip -l "$IPA" | tee .artifacts/logs/ipa-contents.log

DSYM=""
for candidate in "$DERIVED/Build/Products/Release-iphoneos/"*.app.dSYM; do
  if [[ -d "$candidate" ]]; then
    DSYM="$candidate"
    break
  fi
done
if [[ -n "$DSYM" && -d "$DSYM" ]]; then
  ditto -c -k --sequesterRsrc --keepParent \
    "$DSYM" "$RELEASE/ChatGPT-Legacy-v${VERSION}-dSYM.zip"
fi

PLIST="$APP/Info.plist"
EXECUTABLE="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
DEVICE_FAMILY="$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$PLIST")"
if [[ "$DEVICE_FAMILY" != "1" ]]; then
  echo "Release must target iPhone only; found UIDeviceFamily[0]=$DEVICE_FAMILY." >&2
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:1' "$PLIST" >/dev/null 2>&1; then
  echo "Release unexpectedly contains a second UIDeviceFamily entry." >&2
  exit 1
fi
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST")"
LAUNCH_STORYBOARD="$(/usr/libexec/PlistBuddy -c 'Print :UILaunchStoryboardName' "$PLIST")"
REQUIRED_ARCH="$(/usr/libexec/PlistBuddy -c 'Print :UIRequiredDeviceCapabilities:0' "$PLIST")"
ARCHITECTURES="$(lipo -archs "$EXECUTABLE")"

[[ "$BUNDLE_ID" == "io.github.j0shuasyson.ChatGPTLegacy" ]]
[[ "$APP_VERSION" == "$VERSION" ]]
[[ "$BUILD_NUMBER" == "1" ]]
[[ "$MINIMUM_OS" == "15.0" ]]
[[ "$LAUNCH_STORYBOARD" == "LaunchScreen" ]]
[[ "$REQUIRED_ARCH" == "arm64" ]]
[[ "$ARCHITECTURES" == "arm64" ]]
{
  echo "ChatGPT Legacy v$VERSION release evidence"
  echo "Built: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "App: $APP"
  echo
  echo "Info.plist:"
  plutil -p "$APP/Info.plist"
  echo
  echo "Code signature:"
  /usr/bin/codesign -d --verbose=4 "$APP" 2>&1
  echo
  echo "Architectures:"
  echo "$ARCHITECTURES"
  echo
  echo "Device family: iPhone only ($DEVICE_FAMILY)"
  echo
  echo "Minimum OS load command:"
  otool -l "$EXECUTABLE" | awk '/LC_BUILD_VERSION/{show=1;count=0} show{print;count++} count==6{show=0}'
  echo
  echo "UUIDs:"
  dwarfdump --uuid "$EXECUTABLE"
} | tee "$RELEASE/release-evidence.txt"

test -s "$IPA"
