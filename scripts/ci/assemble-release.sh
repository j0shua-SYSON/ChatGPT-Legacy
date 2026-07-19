#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
RELEASE="$ROOT/.artifacts/release"
mkdir -p "$RELEASE" .artifacts/evidence-bundle

if find .artifacts/screenshots .artifacts/video-frames -type f -name '*.png' -print -quit | grep -q .; then
  ditto -c -k --sequesterRsrc \
    .artifacts/screenshots "$RELEASE/ChatGPT-Legacy-v${VERSION}-screenshots.zip"
fi
if [[ -s .artifacts/ui-tour.mp4 ]]; then
  cp .artifacts/ui-tour.mp4 "$RELEASE/ChatGPT-Legacy-v${VERSION}-ui-tour.mp4"
fi

for file in \
  .artifacts/logs/xcode-version.log \
  .artifacts/logs/simulator-selection.log \
  .artifacts/logs/analyze.log \
  .artifacts/logs/full-tests-summary.log \
  .artifacts/logs/ui-tour-test.log \
  .artifacts/logs/visual-evidence-files.log \
  .artifacts/coverage.json; do
  [[ -f "$file" ]] && cp "$file" .artifacts/evidence-bundle/
done

cat > .artifacts/evidence-bundle/README.md <<EOF
# ChatGPT Legacy v$VERSION test evidence

This bundle was produced by GitHub Actions from commit \`${GITHUB_SHA:-unknown}\`.
The gate ran Xcode static analysis, the full XCTest and XCUITest suite, exact
414x736 and 320x568 visual renders, the premium UI tour a second time while
recording video, a generic arm64 Release build, ad-hoc code-sign verification,
and IPA ZIP integrity inspection. Full \`.xcresult\` bundles remain attached to
the Actions run.
EOF

ditto -c -k --sequesterRsrc \
  .artifacts/evidence-bundle \
  "$RELEASE/ChatGPT-Legacy-v${VERSION}-test-evidence.zip"

(
  cd "$RELEASE"
  : > SHA256SUMS.txt
  for file in *; do
    [[ "$file" == "SHA256SUMS.txt" || ! -f "$file" ]] && continue
    shasum -a 256 "$file" >> SHA256SUMS.txt
  done
)

cat "$RELEASE/SHA256SUMS.txt"
test -s "$RELEASE/SHA256SUMS.txt"
