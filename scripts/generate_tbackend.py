#!/usr/bin/env python3
"""Generate Thermion's TBackend C enum from Filament's backend::Backend enum.

Proof of concept for keeping the C API's mirrored enums in sync with Filament
(scoped to TBackend only). Reads the Backend enum from the pinned Filament
version's headers via clang's JSON AST dump — no dependencies beyond a C++
clang and the Python standard library.

Modes:
  (default)  print the generated `enum TBackend { ... };` block
  --check    diff the generated block against the one committed in
             thermion_dart/native/include/c_api/TEngine.h and exit non-zero
             with a clear message if they differ (used by `make
             tbackend-check` and CI)
  --write    replace the committed enum block in TEngine.h with the generated
             one

Filament headers: by default the pinned release artifact is downloaded from
the project's R2 store (same URL scheme as thermion_dart/hook/build.dart) and
only its include/ tree is extracted, to ~/.cache/thermion/tbackend (override
with THERMION_TBACKEND_CACHE). Pass --filament-include DIR (repeatable) to
use existing include roots instead — e.g. a filament git checkout's
filament/backend/include, libs/utils/include and libs/math/include, or a
previously extracted artifact include dir.

The comparison in --check mode is on names/values/order, not byte layout:
comments and whitespace are normalized away, so hand-polished doc comments in
TEngine.h do not fail the check (regenerating with --write would adopt
Filament's comment wording).
"""

import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TENGINE_H = os.path.join(REPO_ROOT, "thermion_dart", "native", "include", "c_api", "TEngine.h")
FILAMENT_VERSION_FILE = os.path.join(REPO_ROOT, "filament.version")

# Same R2 base URL as thermion_dart/hook/build.dart (_getLibraryUrl). Only the
# header tree is used; any platform's zip would do, linux release is the
# smallest conventional one.
R2_BASE = "https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev"
FILAMENT_PLATFORM = "linux-release"

# Where the Backend enum may live, in probe order. v1.77.2 defines it in
# backend/DriverEnums.h; newer Filament moves it to backend/Backend.h.
HEADER_CANDIDATES = ("backend/Backend.h", "backend/DriverEnums.h")

ENUM_NAME = "TBackend"
ENUM_RE = re.compile(r"enum\s+" + ENUM_NAME + r"\s*\{(.*?)\};", re.DOTALL)


def filament_version():
    with open(FILAMENT_VERSION_FILE) as f:
        parts = f.read().split()
    return parts[1]


def ensure_filament_include(requested, version, cache_root):
    if requested:
        for root in requested:
            for c in HEADER_CANDIDATES:
                if os.path.exists(os.path.join(root, c)):
                    return requested
        sys.exit(
            "error: no Backend enum header (%s) under any of %s"
            % (" or ".join(HEADER_CANDIDATES), ", ".join(requested))
        )
    include_dir = os.path.join(cache_root, version, "include")
    if os.path.exists(os.path.join(include_dir, "backend", "DriverEnums.h")):
        return [include_dir]
    url = "%s/filament-%s-%s.zip" % (R2_BASE, version, FILAMENT_PLATFORM)
    cache_dir = os.path.dirname(include_dir)
    os.makedirs(cache_dir, exist_ok=True)
    zip_path = os.path.join(cache_dir, os.path.basename(url))
    print("downloading %s" % url, file=sys.stderr)
    last_err = None
    for attempt in range(3):
        try:
            # R2 rejects urllib's default "Python-urllib/x" User-Agent with 403.
            req = urllib.request.Request(url, headers={"User-Agent": "thermion-tbackend-check"})
            with urllib.request.urlopen(req) as resp, open(zip_path, "wb") as out:
                shutil.copyfileobj(resp, out)
            break
        except Exception as e:  # noqa: BLE001 - report and retry
            last_err = e
    else:
        sys.exit("error: failed to download %s: %s" % (url, last_err))
    with zipfile.ZipFile(zip_path) as z:
        members = [m for m in z.namelist() if m.startswith("include/")]
        z.extractall(cache_dir, members=members)
    os.remove(zip_path)
    return [include_dir]


def dump_backend_enum(include_dirs, clang):
    """Run clang's JSON AST dump and return [(name, value, comment), ...]."""
    header = next(
        (c for c in HEADER_CANDIDATES if any(os.path.exists(os.path.join(d, c)) for d in include_dirs)),
        None,
    )
    if header is None:
        sys.exit(
            "error: no Backend enum header (%s) under %s"
            % (" or ".join(HEADER_CANDIDATES), ", ".join(include_dirs))
        )
    # -ast-dump-filter keeps the JSON to just the Backend EnumDecl (without it
    # the dump includes every transitive std/library header, hundreds of MB).
    cmd = [
        clang, "-x", "c++", "-std=c++17", "-fsyntax-only",
    ]
    for d in include_dirs:
        cmd += ["-I", d]
    cmd += [
        "-Xclang", "-ast-dump-filter=Backend", "-Xclang", "-ast-dump=json",
        os.path.join(next(d for d in include_dirs if os.path.exists(os.path.join(d, header))), header),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(
            "error: clang AST dump failed:\n%s\n%s" % (proc.stdout, proc.stderr)
        )
    try:
        doc = json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        sys.exit("error: could not parse clang AST JSON: %s" % e)
    if doc.get("kind") != "EnumDecl" or doc.get("name") != "Backend":
        sys.exit(
            "error: expected the filtered AST dump to contain the Backend "
            "EnumDecl, got %s" % doc.get("kind")
        )
    constants = []
    for node in doc.get("inner", []):
        if node.get("kind") != "EnumConstantDecl":
            continue
        # Guard against -ast-dump-filter matching some other decl named
        # "Backend" (e.g. from a transitively included std header): every
        # constant of filament::backend::Backend is typed with it.
        qual = node.get("type", {}).get("qualType", "")
        if "backend::Backend" not in qual:
            sys.exit(
                "error: filtered EnumDecl is not filament::backend::Backend "
                "(constant %s has type %r)" % (node.get("name"), qual)
            )
        constants.append((node["name"], constant_value(node), comment_text(node)))
    if not constants:
        sys.exit("error: Backend enum in %s has no constants" % header)
    return header, constants


def constant_value(node):
    # clang's JSON dump stores enum initializer values in a nested ConstantExpr
    # ("value" is a decimal string); older dumps expose "value" directly.
    for inner in node.get("inner", []):
        if inner.get("kind") == "ConstantExpr":
            return int(inner["value"])
    return int(node["value"])


def comment_text(node):
    # Trailing //!< comments appear as a FullComment child; concatenate its
    # TextComment leaves.
    for inner in node.get("inner", []):
        if inner.get("kind") == "FullComment":
            texts = []

            def grab(n):
                if n.get("kind") == "TextComment" and n.get("text"):
                    texts.append(n["text"].strip())
                for v in n.get("inner", []):
                    grab(v)

            grab(inner)
            return " ".join(t for t in texts if t)
    return ""


def emit_enum_block(constants):
    entries = []
    for name, value, comment in constants:
        entry = "BACKEND_%s = %d," % (name, value)
        entries.append((entry, comment))
    width = max(len(e) for e, _ in entries)
    lines = ["enum %s {" % ENUM_NAME]
    for entry, comment in entries:
        line = "    %-*s  //!< %s" % (width, entry, comment) if comment else "    %s" % entry
        lines.append(line)
    lines.append("};")
    return "\n".join(lines)


def normalize(block):
    """Reduce an enum block to names/values/order so comment wording and
    column alignment don't affect the comparison."""
    out = []
    for m in re.finditer(r"(\w+)\s*=\s*(-?\d+)", block):
        out.append("%s=%s" % (m.group(1), m.group(2)))
    return out


def committed_block():
    with open(TENGINE_H) as f:
        src = f.read()
    m = ENUM_RE.search(src)
    if not m:
        sys.exit("error: could not find 'enum %s { ... };' in %s" % (ENUM_NAME, TENGINE_H))
    return m.group(0)


def write_committed_block(generated):
    with open(TENGINE_H) as f:
        src = f.read()
    m = ENUM_RE.search(src)
    if not m:
        sys.exit("error: could not find 'enum %s { ... };' in %s" % (ENUM_NAME, TENGINE_H))
    with open(TENGINE_H, "w") as f:
        f.write(src[: m.start()] + generated + src[m.end() :])


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="verify the committed enum matches the generated one")
    ap.add_argument("--write", action="store_true", help="rewrite the committed enum block in TEngine.h")
    ap.add_argument("--filament-include", action="append", default=[], metavar="DIR", help="use this Filament include root instead of downloading the pinned artifact (repeatable, e.g. a filament checkout's backend/include, libs/utils/include and math include roots)")
    ap.add_argument("--clang", default=os.environ.get("CLANG", "clang"))
    args = ap.parse_args()

    version = filament_version()
    cache_root = os.environ.get(
        "THERMION_TBACKEND_CACHE",
        os.path.join(os.path.expanduser("~"), ".cache", "thermion", "tbackend"),
    )
    include_dirs = ensure_filament_include(args.filament_include, version, cache_root)
    header, constants = dump_backend_enum(include_dirs, args.clang)
    generated = emit_enum_block(constants)

    print("# generated from filament %s (%s, filament::backend::Backend)" % (version, header), file=sys.stderr)
    if args.write:
        write_committed_block(generated)
        print("rewrote %s" % TENGINE_H, file=sys.stderr)
        return
    if args.check:
        committed = committed_block()
        if normalize(generated) == normalize(committed):
            print("OK: %s matches filament %s filament::backend::Backend" % (TENGINE_H, version))
            return
        diff = difflib.unified_diff(
            generated.splitlines(),
            committed.splitlines(),
            fromfile="generated (filament %s)" % version,
            tofile="committed (%s)" % os.path.relpath(TENGINE_H, REPO_ROOT),
            lineterm="",
        )
        print(
            "error: TBackend enum in %s is out of sync with filament %s's "
            "filament::backend::Backend.\n"
            "Fix: run `python3 scripts/generate_tbackend.py --write` (or copy "
            "the generated block into the header by hand), then regenerate "
            "the Dart bindings with `make dart-bindings`.\n\n%s"
            % (os.path.relpath(TENGINE_H, REPO_ROOT), version, "\n".join(diff)),
            file=sys.stderr,
        )
        sys.exit(1)
    print(generated)


if __name__ == "__main__":
    main()
