#!/usr/bin/env bash
set -euo pipefail

# Build the exact wrapper and core expected by the gallery's Dart bindings.
gallery=examples/dart/web_gallery
config="$gallery/.dart_tool/package_config.json"
if [[ ! -f "$config" ]]; then
    echo "Run dart pub get in $gallery before building the gallery engine." >&2
    exit 1
fi

source_dir=$(python3 - "$config" <<'PY'
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urljoin, urlsplit

config = Path(sys.argv[1]).resolve()
for package in json.loads(config.read_text())["packages"]:
    if package["name"] == "reactphysics3d_dart":
        uri = urlsplit(urljoin(config.as_uri(), package["rootUri"]))
        if uri.scheme != "file":
            sys.exit("Expected a local reactphysics3d_dart package.")
        print(unquote(uri.path))
        break
else:
    sys.exit("Run dart pub get to resolve reactphysics3d_dart.")
PY
)

# The upstream build stages generated files alongside its source. Use a copy
# under Thermion's ignored web build tree so it never modifies the Pub cache.
stage="$1"
mkdir -p "$stage"
cp -R "$source_dir/native" "$source_dir/scripts" "$stage/"
bash "$stage/scripts/build_web_artifacts.sh"
