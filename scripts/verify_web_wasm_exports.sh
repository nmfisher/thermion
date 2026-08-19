#!/bin/bash

# Verifies that the freshly linked thermion_dart.wasm actually exports the
# Emscripten keepalive symbols the Dart side calls.
#
# The link runs with -sERROR_ON_UNDEFINED_SYMBOLS=0 and pulls external projects
# in through -Wl,--whole-archive, so a misconfigured build fails *silently*:
# the WASM still links, and the missing symbols only surface as a runtime error
# in the browser. This turns that into a build failure.
#
# Emscripten minifies the names in the wasm export section, so the wasm itself
# cannot be grepped; the JS glue instead assigns every keepalive onto the
# Module object as `Module["_name"]=wasmExports["<minified>"]`. Matching that
# assignment proves the symbol came from the wasm export table (a reference to
# an undefined symbol produces no such line).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <wasm-output-dir> [symbol ...]"
  echo "Example: $0 thermion_dart/native/web/build/build/out _rp3d_world_update"
  exit 1
fi

OUT_DIR="$1"
shift

GLUE="$OUT_DIR/thermion_dart.js"
WASM="$OUT_DIR/thermion_dart.wasm"

for f in "$GLUE" "$WASM"; do
  if [ ! -f "$f" ]; then
    echo "Error: $f not found -- did the web build run?"
    exit 1
  fi
done

exported() {
  grep -c "Module\[\"$1\"\]=wasmExports" "$GLUE" || true
}

# -o | wc -l, not -c: the glue is minified onto a single line, so grep -c
# would report 1 no matter how many exports matched.
count_thermion() {
  grep -o 'Module\["_Thermion' "$GLUE" | wc -l
}

count_rp3d() {
  grep -o 'Module\["_rp3d_' "$GLUE" | wc -l
}

echo "WASM: $WASM ($(du -h "$WASM" | cut -f1))"
echo "Exported _Thermion* symbols: $(count_thermion)"
echo "Exported _rp3d_* symbols:    $(count_rp3d)"

if [ "$(count_thermion)" -eq 0 ]; then
  echo "Error: no _Thermion* exports found in $GLUE"
  exit 1
fi

STATUS=0
for symbol in "$@"; do
  if [ "$(exported "$symbol")" -ge 1 ]; then
    echo "  OK    $symbol"
  else
    echo "  MISS  $symbol"
    STATUS=1
  fi
done

if [ "$STATUS" -ne 0 ]; then
  echo "Error: the WASM is missing required exports (see MISS lines above)"
  exit 1
fi

echo "Export verification passed."
