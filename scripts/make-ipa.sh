#!/usr/bin/env bash
# Builds an unsigned CodeIsrael.ipa for AltStore (AltStore signs it with the user's own Apple ID when installing).
# Usage: [VERSION=1.2 BUILD=34] scripts/make-ipa.sh [output-dir]   (default: build/)
set -euo pipefail
out="${1:-build}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cd "$(dirname "$0")/../ios"
derived="$(mktemp -d)"

xcodegen generate >/dev/null
# `-target` rather than `-scheme`: it does not depend on the generated scheme list.
xcodebuild -project CodeIsrael.xcodeproj -target CodeIsrael -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" SYMROOT="$derived" \
  ${VERSION:+MARKETING_VERSION="$VERSION"} ${BUILD:+CURRENT_PROJECT_VERSION="$BUILD"} build | tail -3

app="$derived/Release-iphoneos/CodeIsrael.app"
[ -d "$app" ] || { echo "Build failed: $app not found" >&2; exit 1; }
work="$(mktemp -d)"
mkdir "$work/Payload"
cp -R "$app" "$work/Payload/"
rm -f "$out/CodeIsrael.ipa"
(cd "$work" && zip -qry "$out/CodeIsrael.ipa" Payload)
echo "$out/CodeIsrael.ipa"
