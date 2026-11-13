#!/usr/bin/env python3
"""Generate Thermion's C and public Dart backend mirrors from Filament.

Keeps the C enum, generated native/JS constants and public Dart Backend in
sync with the pinned filament::backend::Backend. Reads Clang's JSON AST dump
using only a C++ Clang and the Python standard library.

Modes:
  (default)  print the generated `enum TBackend { ... };` block
  --check    verify C, native/JS binding constants and generated public Dart
             Backend members against Filament (used by make tbackend-check)
  --write    replace the C enum and generate the public Dart Backend; run
             make bindings afterward to regenerate native and JS constants

Filament headers: by default the pinned release artifact is downloaded from
the project's R2 store (same URL scheme as thermion_dart/hook/build.dart) and
only its include/ tree is extracted, to ~/.cache/thermion/tbackend (override
with THERMION_TBACKEND_CACHE). Pass --filament-include DIR (repeatable) to
use existing include roots instead — e.g. a filament git checkout's
filament/backend/include, libs/utils/include and libs/math/include, or a
previously extracted artifact include dir.

C and binding comparisons validate the complete supported syntax and compare
names, values and order, ignoring comments and whitespace. The public Dart
file must match the generated enum, including every member and fromValue.
The C enum accepts decimal integers and implicit numbering; expressions and
other unsupported syntax fail explicitly instead of being partially matched.
"""

import argparse
import difflib
from pathlib import Path
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
DART_BACKEND = Path(REPO_ROOT) / "thermion_dart/lib/src/filament/src/interface/backend.g.dart"
BINDINGS = [Path(REPO_ROOT) / "thermion_dart/lib/src/bindings/src" / name for name in (
    "thermion_dart_ffi.g.dart", "thermion_dart_js_interop.g.dart",
)]
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
    # Filter by the qualified name to keep the dump small. Clang may still
    # return several declarations (e.g. BackendCapabilities), so select the
    # exact enum from the JSON document stream below.
    cmd = [
        clang, "-x", "c++", "-std=c++17", "-fsyntax-only",
    ]
    for d in include_dirs:
        cmd += ["-I", d]
    cmd += [
        "-Xclang", "-ast-dump-filter=filament::backend::Backend", "-Xclang", "-ast-dump=json",
        os.path.join(next(d for d in include_dirs if os.path.exists(os.path.join(d, header))), header),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(
            "error: clang AST dump failed:\n%s\n%s" % (proc.stdout, proc.stderr)
        )
    try:
        declarations = json_documents(proc.stdout)
        candidates = []
        for declaration in declarations:
            for node in walk(declaration):
                members = [child for child in node.get("inner", []) if child.get("kind") == "EnumConstantDecl"]
                if (node.get("kind") == "EnumDecl" and node.get("name") == "Backend" and members
                        and all(member.get("type", {}).get("qualType") == "filament::backend::Backend" for member in members)):
                    candidates.append(members)
        if len(candidates) != 1:
            raise ValueError("expected one definition of filament::backend::Backend, found %d" % len(candidates))
        constants = []
        previous = -1
        for node in candidates[0]:
            value = constant_value(node, previous)
            constants.append((node["name"], value, comment_text(node)))
            previous = value
    except (ValueError, KeyError) as error:
        sys.exit("error: could not extract filament::backend::Backend: %s" % error)
    return header, constants


def json_documents(text):
    """Clang emits a stream of JSON documents when a filter matches several declarations."""
    decoder = json.JSONDecoder()
    offset = 0
    while offset < len(text):
        while offset < len(text) and text[offset].isspace():
            offset += 1
        if offset == len(text):
            break
        document, offset = decoder.raw_decode(text, offset)
        yield document


def walk(node):
    yield node
    for child in node.get("inner", []):
        yield from walk(child)


def constant_value(node, previous=-1):
    # Explicit initializers contain a compiler-evaluated ConstantExpr, possibly
    # behind a cast. Implicit constants follow the previous enumerator.
    for child in walk(node):
        if child.get("kind") == "ConstantExpr" and "value" in child:
            return int(child["value"])
    if "value" in node:
        return int(node["value"])
    if any(child.get("kind") != "FullComment" for child in node.get("inner", [])):
        raise ValueError("missing evaluated initializer for %s" % node["name"])
    return previous + 1


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


def without_comments(source):
    # Preserve offsets so replacement edits the real enum, not a commented copy.
    return re.sub(r"//[^\n]*|/\*.*?\*/", lambda match: "".join("\n" if c == "\n" else " " for c in match[0]), source, flags=re.DOTALL)


def enum_match(source):
    matches = list(ENUM_RE.finditer(without_comments(source)))
    if len(matches) != 1:
        raise ValueError("expected exactly one enum TBackend definition")
    return matches[0]


def normalize(block):
    """Validate the entire supported C enum syntax before comparing values.

    Generated decimal integers and implicit numbering are supported. Expressions
    and other syntax are rejected, never partially matched or silently ignored.
    """
    match = enum_match(block)
    body = match[1].strip()
    entries = body.split(",")
    if entries[-1].strip() == "":
        entries.pop()
    result = []
    previous = -1
    names = set()
    for entry in entries:
        member = re.fullmatch(r"\s*(BACKEND_[A-Za-z_][A-Za-z0-9_]*)(?:\s*=\s*(-?(?:0|[1-9][0-9]*)))?\s*", entry)
        if not member:
            raise ValueError("unsupported TBackend enumerator: %r; use generated decimal integers or implicit numbering" % entry.strip())
        name, explicit = member.groups()
        if name in names:
            raise ValueError("duplicate TBackend member: %s" % name)
        names.add(name)
        value = int(explicit) if explicit is not None else previous + 1
        result.append("%s=%d" % (name, value))
        previous = value
    return result


def committed_block():
    source = Path(TENGINE_H).read_text()
    match = enum_match(source)
    return source[match.start():match.end()]


def write_committed_block(generated):
    source = Path(TENGINE_H).read_text()
    match = enum_match(source)
    Path(TENGINE_H).write_text(source[:match.start()] + generated + source[match.end():])


def emit_dart_backend(constants):
    lines = ["// GENERATED by scripts/generate_tbackend.py. Do not edit.",
             "import '../../../bindings/bindings.dart' as bindings;", "", "enum Backend {"]
    for index, (name, _, comment) in enumerate(constants):
        if comment:
            lines.append("  /// %s" % comment)
        lines.append("  %s(bindings.TBackend.BACKEND_%s)%s" % (name, name, ";" if index == len(constants) - 1 else ","))
        lines.append("")
    lines.extend(["  final int value;", "  const Backend(this.value);", "",
                  "  static Backend fromValue(int value) {",
                  "    for (final backend in values) {",
                  "      if (backend.value == value) return backend;",
                  "    }",
                  '    throw ArgumentError("Unknown value for TBackend: $value");',
                  "  }", "}", ""])
    return "\n".join(lines)


def binding_constants(path):
    source = without_comments(path.read_text())
    match = re.search(r"class\s+TBackend\s*\{([^}]*)\}", source, re.DOTALL)
    if not match:
        raise ValueError("missing generated TBackend in %s" % path)
    result = []
    for entry in match[1].split(";"):
        if not entry.strip():
            continue
        member = re.fullmatch(r"\s*static\s+const\s+(BACKEND_[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(-?(?:0|[1-9][0-9]*))\s*", entry)
        if not member:
            raise ValueError("unsupported generated TBackend constant in %s: %r" % (path, entry.strip()))
        result.append("%s=%d" % (member[1], int(member[2])))
    return result


def check_mirrors(constants):
    expected = normalize(emit_enum_block(constants))
    failures = []
    for path, actual in [(Path(TENGINE_H), normalize(committed_block()))] + [(path, binding_constants(path)) for path in BINDINGS]:
        if actual != expected:
            failures.append("%s:\n%s" % (path, "\n".join(difflib.unified_diff(expected, actual, fromfile="Filament", tofile="committed", lineterm=""))))
    generated = emit_dart_backend(constants)
    if not DART_BACKEND.exists() or DART_BACKEND.read_text() != generated:
        failures.append("%s: generated public Backend members or mapping are stale" % DART_BACKEND)
    return failures


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="verify the entire C/bindings/public Dart mirror chain")
    ap.add_argument("--write", action="store_true", help="regenerate TBackend and public Dart Backend")
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
    try:
        if args.write:
            write_committed_block(generated)
            DART_BACKEND.write_text(emit_dart_backend(constants))
            print("rewrote %s and %s; run make bindings next" % (TENGINE_H, DART_BACKEND), file=sys.stderr)
            return
        if args.check:
            failures = check_mirrors(constants)
            if failures:
                sys.exit("error: Backend mirror chain is out of sync:\n%s\nFix: run python3 scripts/generate_tbackend.py --write, then make bindings." % "\n".join(failures))
            print("OK: Filament -> TBackend -> native/JS bindings -> public Dart Backend")
            return
    except ValueError as error:
        sys.exit("error: %s" % error)
    print(generated)


if __name__ == "__main__":
    main()
