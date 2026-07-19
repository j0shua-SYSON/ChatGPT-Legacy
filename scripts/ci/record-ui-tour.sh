#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .artifacts/simulator.env

VIDEO="$ROOT/.artifacts/ui-tour.mp4"
rm -f "$VIDEO"
xcrun simctl io "$SIM_ID" recordVideo --codec=h264 --force "$VIDEO" \
  >.artifacts/logs/video-recorder.log 2>&1 &
VIDEO_PID=$!

finish_video() {
  if kill -0 "$VIDEO_PID" 2>/dev/null; then
    kill -INT "$VIDEO_PID" 2>/dev/null || true
    wait "$VIDEO_PID" 2>/dev/null || true
  fi
}
trap finish_video EXIT
sleep 1

set +e
set -o pipefail
xcodebuild \
  -project ChatGPTLegacy.xcodeproj \
  -scheme ChatGPTLegacy \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath .derived-data/simulator \
  -only-testing:ChatGPTLegacyUITests/ChatGPTLegacyUITests/testPremiumUITour \
  -resultBundlePath .artifacts/UITour.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test-without-building | tee .artifacts/logs/ui-tour-test.log
TEST_STATUS=${PIPESTATUS[0]}
set -e

finish_video
trap - EXIT
[[ $TEST_STATUS -eq 0 ]]
test -s "$VIDEO"
