#!/bin/bash
# Upload a locally-built Filament zip to R2 under its CONTENT-ADDRESSED key:
#
#   filament-<version>-<platform>-<variant>-<sha256[:16]>.zip
#
# plus a `<zip>.sha256` sidecar (full digest) next to it in the output dir.
# Content-addressed keys are immutable: uploading never overwrites an
# artifact anyone may be using. Consumers select artifacts via the pin file
# thermion_dart/filament.libs.json (see lib/src/hooks/filament_artifacts.dart);
# use publish-filament-to-r2.yml to record published digests into the pin.
#
# Usage: upload_filament_hashed.sh <zip-path>
# Env:   R2_BUCKET_NAME, R2_ENDPOINT, AWS_* credentials (as in CI).
set -euo pipefail

zip="$1"
if [ ! -f "$zip" ]; then
  echo "ERROR: no such file: $zip" >&2
  exit 1
fi
base="$(basename "$zip" .zip)"
case "$base" in
  filament-*-release|filament-*-debug) ;;
  *) echo "ERROR: not a Filament artifact name: $base" >&2; exit 1 ;;
esac

if command -v sha256sum >/dev/null 2>&1; then
  sha="$(sha256sum "$zip" | cut -d' ' -f1)"
else
  sha="$(shasum -a 256 "$zip" | cut -d' ' -f1)"
fi
hash16="${sha:0:16}"
key="${base}-${hash16}.zip"

# Full-digest sidecar travels with the GitHub artifact so the publish
# workflow can cross-check its own computation.
printf '%s  %s\n' "$sha" "$(basename "$zip")" > "${zip}.sha256"

echo "Uploading $key (sha256 $sha)"
aws s3 cp "$zip" "s3://${R2_BUCKET_NAME}/${key}" --endpoint-url "${R2_ENDPOINT}"
echo "Published s3://${R2_BUCKET_NAME}/${key}"
