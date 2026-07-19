#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .artifacts/simulator.env

VIDEO="$ROOT/.artifacts/ui-tour.mp4"
TEST_LOG="$ROOT/.artifacts/logs/ui-tour-test.log"
TEST_STATUS_FILE="$ROOT/.artifacts/logs/ui-tour-test.status"
rm -f "$VIDEO" "$TEST_LOG" "$TEST_STATUS_FILE"

(
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
    test-without-building 2>&1 | tee "$TEST_LOG"
  status=${PIPESTATUS[0]}
  printf '%s\n' "$status" > "$TEST_STATUS_FILE"
  exit "$status"
) &
TEST_PID=$!

wait_for_marker() {
  local marker="$1"
  local attempts="${2:-360}"
  local index
  for ((index = 0; index < attempts; index++)); do
    if [[ -s "$TEST_LOG" ]] && grep -q "$marker" "$TEST_LOG"; then
      return 0
    fi
    if ! kill -0 "$TEST_PID" 2>/dev/null; then
      return 1
    fi
    sleep 0.25
  done
  return 1
}

if ! wait_for_marker CHATGPT_LEGACY_VIDEO_READY; then
  wait "$TEST_PID" || true
  echo "UI tour never reached the ready marker." >&2
  exit 1
fi

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

if ! wait_for_marker CHATGPT_LEGACY_VIDEO_FINISHED 240; then
  finish_video
  wait "$TEST_PID" || true
  echo "UI tour never reached the finished marker." >&2
  exit 1
fi

finish_video
trap - EXIT
wait "$TEST_PID" || true
TEST_STATUS="$(cat "$TEST_STATUS_FILE" 2>/dev/null || printf '1')"
[[ "$TEST_STATUS" -eq 0 ]]
test -s "$VIDEO"
