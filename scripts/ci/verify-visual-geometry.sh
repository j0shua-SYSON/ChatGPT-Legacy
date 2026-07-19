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

full_directory=.artifacts/screenshots/full
tour_directory=.artifacts/screenshots/tour
iphone_plus="$(attachment_path "$full_directory" 'chat-414x736-light')"
compact="$(attachment_path "$full_directory" 'chat-320x568-light')"
tour_chat="$(attachment_path "$tour_directory" 'tour-01-chat')"
first_video_frame="$(find .artifacts/video-frames -type f -name '*.png' -print -quit)"
[[ -n "$first_video_frame" && -f "$first_video_frame" ]]

{
  expect_dimensions "$iphone_plus" "1242x2208"
  expect_dimensions "$compact" "960x1704"
  reject_compatibility_canvas "$tour_chat"
  reject_compatibility_canvas "$first_video_frame"
} | tee .artifacts/logs/visual-geometry.log
