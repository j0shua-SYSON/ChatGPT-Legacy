#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p .artifacts/logs

xcrun simctl list devices available --json > .artifacts/sim-devices.json

PREFERRED_NAMES=(
  "iPhone 8 Plus"
  "iPhone 11 Pro Max"
  "iPhone 14 Plus"
  "iPhone 17 Pro Max"
  "iPhone 17 Pro"
  "iPhone 17"
  "iPhone Air"
  "iPhone 16 Pro Max"
  "iPhone 16 Plus"
  "iPhone 16 Pro"
  "iPhone 16e"
  "iPhone 15 Pro"
)

selection=""
for name in "${PREFERRED_NAMES[@]}"; do
  selection="$(
    jq -r --arg name "$name" '
      [
        .devices | to_entries[] | .key as $runtime | .value[] |
        select(.isAvailable and .name == $name) |
        [.udid, .deviceTypeIdentifier, $runtime, .name]
      ][0] | if . == null then empty else @tsv end
    ' .artifacts/sim-devices.json
  )"
  [[ -n "$selection" ]] && break
done

if [[ -z "$selection" ]]; then
  selection="$(
    jq -r '
      [
        .devices | to_entries[] | .key as $runtime | .value[] |
        select(.isAvailable and (.name | startswith("iPhone"))) |
        [.udid, .deviceTypeIdentifier, $runtime, .name]
      ][0] | if . == null then empty else @tsv end
    ' .artifacts/sim-devices.json
  )"
fi

if [[ -z "$selection" ]]; then
  echo "No preinstalled iPhone simulator is available." >&2
  xcrun simctl list devices available >&2
  exit 1
fi

IFS=$'\t' read -r SIM_ID SIM_TYPE SIM_RUNTIME SIM_NAME <<< "$selection"
if [[ ! "$SIM_ID" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  echo "Simulator selection returned an invalid UUID: $SIM_ID" >&2
  exit 1
fi

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
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
  echo "Device: $SIM_NAME"
  echo "Device type: $SIM_TYPE"
  echo "Runtime: $SIM_RUNTIME"
  xcrun simctl list devices | grep -F "$SIM_ID" || true
} | tee .artifacts/logs/simulator-selection.log
