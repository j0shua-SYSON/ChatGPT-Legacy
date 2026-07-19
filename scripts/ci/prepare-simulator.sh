#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p .artifacts/logs

RUNTIMES=()
while IFS= read -r runtime; do
  RUNTIMES+=("$runtime")
done < <(
  xcrun simctl list runtimes --json |
    jq -r '.runtimes | map(select(.isAvailable and (.identifier | contains("iOS")))) | sort_by(.version | split(".") | map(tonumber)) | reverse | .[].identifier'
)

if [[ ${#RUNTIMES[@]} -eq 0 ]]; then
  echo "No available iOS Simulator runtime." >&2
  exit 1
fi

PREFERRED_TYPES=(
  com.apple.CoreSimulator.SimDeviceType.iPhone-8-Plus
  com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max
  com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus
  com.apple.CoreSimulator.SimDeviceType.iPhone-16-Plus
  com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro
  com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro
)

SIM_ID=""
SIM_TYPE=""
SIM_RUNTIME=""
: > .artifacts/logs/simulator-create.log
for type in "${PREFERRED_TYPES[@]}"; do
  if ! xcrun simctl list devicetypes --json | jq -e --arg id "$type" '.devicetypes[] | select(.identifier == $id)' >/dev/null; then
    continue
  fi
  for runtime in "${RUNTIMES[@]}"; do
    candidate="$(xcrun simctl create "ChatGPT Legacy CI" "$type" "$runtime" 2>>.artifacts/logs/simulator-create.log || true)"
    if [[ -n "$candidate" ]]; then
      SIM_ID="$candidate"
      SIM_TYPE="$type"
      SIM_RUNTIME="$runtime"
      break 2
    fi
  done
done

if [[ -z "$SIM_ID" ]]; then
  echo "Could not create a compatible iPhone simulator." >&2
  cat .artifacts/logs/simulator-create.log >&2
  exit 1
fi

xcrun simctl boot "$SIM_ID"
xcrun simctl bootstatus "$SIM_ID" -b
xcrun simctl status_bar "$SIM_ID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 2>/dev/null || true

cat > .artifacts/simulator.env <<EOF
SIM_ID=$SIM_ID
SIM_TYPE=$SIM_TYPE
SIM_RUNTIME=$SIM_RUNTIME
EOF

{
  echo "Simulator ID: $SIM_ID"
  echo "Device type: $SIM_TYPE"
  echo "Runtime: $SIM_RUNTIME"
  xcrun simctl list devices | grep -F "$SIM_ID" || true
} | tee .artifacts/logs/simulator-selection.log
