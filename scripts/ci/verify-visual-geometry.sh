#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

attachment_path() {
  local directory="$1"
  local needle="$2"
  local manifest="$directory/manifest.json"
  local filename

  [[ -f "$manifest" ]] || {
    echo "Attachment manifest is missing: $manifest" >&2
    return 1
  }
  filename="$(
    jq -r --arg needle "$needle" '
      [
        .[].attachments[] |
        select((.suggestedHumanReadableName // "") | contains($needle)) |
        .exportedFileName
      ][0] // empty
    ' "$manifest"
  )"
  [[ -n "$filename" && -f "$directory/$filename" ]] || {
    echo "No retained screenshot contains name: $needle" >&2
    return 1
  }
  printf '%s\n' "$directory/$filename"
}

image_dimensions() {
  local image="$1"
  local metadata width height
  metadata="$(sips -g pixelWidth -g pixelHeight "$image")"
  width="$(awk '/pixelWidth:/{print $2}' <<<"$metadata")"
  height="$(awk '/pixelHeight:/{print $2}' <<<"$metadata")"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]]
  printf '%sx%s\n' "$width" "$height"
}

expect_dimensions() {
  local image="$1"
  local expected="$2"
  local actual
  actual="$(image_dimensions "$image")"
  echo "$(basename "$image"): $actual (expected $expected)"
  [[ "$actual" == "$expected" ]] || {
    echo "Unexpected retained screenshot geometry." >&2
    return 1
  }
}

reject_compatibility_canvas() {
  local image="$1"
  local actual
  actual="$(image_dimensions "$image")"
  echo "$(basename "$image"): $actual (native-runtime check)"
  [[ "$actual" != "960x1440" ]] || {
    echo "Detected the legacy 320x480 compatibility canvas." >&2
    return 1
  }
}

expect_landscape_orientation() {
  local image="$1"
  local actual width height
  actual="$(image_dimensions "$image")"
  width="${actual%x*}"
  height="${actual#*x}"
  echo "$(basename "$image"): $actual (landscape check)"
  (( width > height )) || {
    echo "Retained landscape screenshot is not landscape." >&2
    return 1
  }
}

full_directory=.artifacts/screenshots/full
tour_directory=.artifacts/screenshots/tour
iphone_plus="$(attachment_path "$full_directory" 'chat-414x736-light')"
iphone_plus_dark="$(attachment_path "$full_directory" 'chat-414x736-dark')"
compact="$(attachment_path "$full_directory" 'chat-320x568-light')"
oauth_code="$(attachment_path "$full_directory" 'oauth-device-code')"
dark_runtime="$(attachment_path "$full_directory" 'chat-dark')"
landscape_runtime="$(attachment_path "$full_directory" 'chat-landscape')"
tour_chat="$(attachment_path "$tour_directory" 'tour-01-chat')"
first_video_frame="$(find .artifacts/video-frames -type f -name '*.png' -print -quit)"
[[ -n "$first_video_frame" && -f "$first_video_frame" ]]

xcrun swiftc \
  -module-cache-path .build/module-cache \
  scripts/ci/VerifyImageAppearance.swift \
  -o .tools/verify-image-appearance \
  -framework AppKit

{
  expect_dimensions "$iphone_plus" "1242x2208"
  expect_dimensions "$iphone_plus_dark" "1242x2208"
  expect_dimensions "$compact" "960x1704"
  reject_compatibility_canvas "$oauth_code"
  reject_compatibility_canvas "$dark_runtime"
  reject_compatibility_canvas "$landscape_runtime"
  expect_landscape_orientation "$landscape_runtime"
  reject_compatibility_canvas "$tour_chat"
  reject_compatibility_canvas "$first_video_frame"
  .tools/verify-image-appearance "$iphone_plus_dark" dark
  .tools/verify-image-appearance "$landscape_runtime" no-black-bars
} | tee .artifacts/logs/visual-geometry.log
