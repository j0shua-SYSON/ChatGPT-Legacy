#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p .artifacts/screenshots/full .artifacts/screenshots/tour .artifacts/video-frames

export_attachments() {
  local source="$1"
  local destination="$2"
  [[ -d "$source" ]] || return 0
  xcrun xcresulttool export attachments \
    --path "$source" \
    --output-path "$destination" \
    >".artifacts/logs/$(basename "$source").attachments.log" 2>&1 || true
}

export_attachments .artifacts/FullTests.xcresult .artifacts/screenshots/full
export_attachments .artifacts/UITour.xcresult .artifacts/screenshots/tour

if [[ -d .artifacts/FullTests.xcresult ]]; then
  xcrun xccov view --report --json .artifacts/FullTests.xcresult \
    > .artifacts/coverage.json 2>.artifacts/logs/coverage.log || true
  ditto -c -k --sequesterRsrc --keepParent \
    .artifacts/FullTests.xcresult .artifacts/FullTests.xcresult.zip || true
fi
if [[ -d .artifacts/UITour.xcresult ]]; then
  ditto -c -k --sequesterRsrc --keepParent \
    .artifacts/UITour.xcresult .artifacts/UITour.xcresult.zip || true
fi

if [[ -s .artifacts/ui-tour.mp4 ]]; then
  xcrun swiftc \
    -module-cache-path .build/module-cache \
    scripts/ci/ExtractVideoFrames.swift \
    -o .tools/extract-video-frames \
    -framework AVFoundation \
    -framework AppKit
  .tools/extract-video-frames \
    .artifacts/ui-tour.mp4 .artifacts/video-frames \
    | tee .artifacts/logs/video-frames.log
fi

find .artifacts/screenshots .artifacts/video-frames \
  -type f -maxdepth 3 -print | sort > .artifacts/logs/visual-evidence-files.log
exit 0
