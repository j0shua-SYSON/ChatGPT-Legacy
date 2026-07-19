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

EXECUTABLE="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
DEVICE_FAMILY="$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$APP/Info.plist")"
if [[ "$DEVICE_FAMILY" != "1" ]]; then
  echo "Release must target iPhone only; found UIDeviceFamily[0]=$DEVICE_FAMILY." >&2
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:1' "$APP/Info.plist" >/dev/null 2>&1; then
  echo "Release unexpectedly contains a second UIDeviceFamily entry." >&2
  exit 1
fi
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
  lipo -archs "$EXECUTABLE"
  echo
  echo "Device family: iPhone only ($DEVICE_FAMILY)"
  echo
  echo "Minimum OS load command:"
  otool -l "$EXECUTABLE" | awk '/LC_BUILD_VERSION/{show=1;count=0} show{print;count++} count==6{show=0}'
  echo
  echo "UUIDs:"
  dwarfdump --uuid "$EXECUTABLE"
} | tee "$RELEASE/release-evidence.txt"

grep -q "arm64" "$RELEASE/release-evidence.txt"
grep -q '"CFBundleShortVersionString" => "1.0.0"' "$RELEASE/release-evidence.txt"
test -s "$IPA"
