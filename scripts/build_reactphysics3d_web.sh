#!/usr/bin/env bash
set -euo pipefail

# Build the exact wrapper and core expected by the physics_basics Dart bindings.
example_dir=examples/dart/physics_basics
config="$example_dir/.dart_tool/package_config.json"
if [[ ! -f "$config" ]]; then
    echo "Run dart pub get in $example_dir before building the physics WASM engine." >&2
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

# Stage the package's native/ tree under Thermion's ignored web build directory
# so CMake never writes into the Pub cache. Published pub.dev releases already
# include prebuilt native/web/libreactphysics3d.a; fall back to building it when
# developing against a source checkout without prebuilt web artifacts.
stage="$1"
rm -rf "$stage"
mkdir -p "$stage"
cp -R "$source_dir/native" "$stage/"
if [[ ! -f "$stage/native/web/libreactphysics3d.a" ]]; then
    if [[ ! -f "$source_dir/scripts/build_web_artifacts.sh" ]]; then
        echo "Missing prebuilt $stage/native/web/libreactphysics3d.a and scripts/build_web_artifacts.sh." >&2
        exit 1
    fi
    cp -R "$source_dir/scripts" "$stage/"
    bash "$stage/scripts/build_web_artifacts.sh"
fi
