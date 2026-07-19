#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .artifacts/simulator.env

DESTINATION="platform=iOS Simulator,id=$SIM_ID"
COMMON=(
  -project ChatGPTLegacy.xcodeproj
  -scheme ChatGPTLegacy
  -configuration Debug
  -destination "$DESTINATION"
  -derivedDataPath .derived-data/simulator
  CODE_SIGNING_ALLOWED=NO
)

set -o pipefail
xcodebuild "${COMMON[@]}" analyze |
  tee .artifacts/logs/analyze.log

xcodebuild "${COMMON[@]}" clean test \
  -resultBundlePath .artifacts/FullTests.xcresult |
  tee .artifacts/logs/full-tests.log

grep -E "(Test Suite|Executed|TEST SUCCEEDED|warning:|error:)" \
  .artifacts/logs/full-tests.log > .artifacts/logs/full-tests-summary.log || true
