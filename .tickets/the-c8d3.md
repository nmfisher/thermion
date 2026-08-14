---
id: the-c8d3
status: in-progress
deps: []
links: []
created: 2026-08-14T11:21:35Z
type: bug
priority: 2
assignee: Nick Fisher
tags: [build, linux, debug, filament]
---
# Fix Linux v1.75.0 debug artifact problem (debug hook builds fail)

Linux debug hook builds fail: the v1.75.0 linux debug R2 artifact has an issue (found during the-0rkw lib-stripping work). Pre-existing, not caused by the stripping change. Investigate the artifact and fix the debug build.


## Details (from the-0rkw proposal work, 2026-08-14)

### The problem

Linux **debug** hook builds fail: the v1.75.0 linux *debug* R2 artifact's
`include/` directory lacks `bluevk/BlueVK.h` (the release artifact has
it). This was seen before any of the lib-stripping edits — it is a
pre-existing problem with the downloaded Filament debug artifact, not
caused by the-0rkw.

### Context

- Filament prebuilt artifacts are downloaded by version (R2 = v1.75.0
  debug in this case). Release has the header, debug does not.
- The debug build fails at compile time when the hook includes
  `<bluevk/BlueVK.h>` (via vulkan headers, e.g. LinuxVulkanContext /
  LinuxVulkanUtils under thermion_dart/native/include/vulkan/linux/).

### What to do

1. Confirm the exact failing include and where it comes from.
2. Fix the debug build. Options to evaluate:
   - Patch/copy the missing header from the release artifact (if the
     debug artifact is just missing a file).
   - Check whether the debug artifact download is corrupted/incomplete
     and re-fetch.
   - Adjust the build hook to tolerate the missing header.
   - Bump/pin the artifact version if the upstream artifact is broken.
3. Verify: `scripts/build_linux.sh --debug` completes; the debug `.so`
   builds and links (ldd -r clean).
4. Note any relationship to the-0rkw's `libraries:` placement change —
   the debug failure predates it, but confirm the debug build works with
   the new hook either way.

### Rules

- Standard: branch + PR (or local-only if Nick says so), never push to
  master/develop directly, never merge.
- Simplified technical English.

## Sandbox brief (for the agent — read this first)

You are a coding agent fixing the Linux debug build. Work on the asb/
branch (e.g. asb/linux-debug-artifact). The ticket above is the spec.

### Steps

1. Reproduce: run `scripts/build_linux.sh --debug` (or the failing hook
   step) and confirm the exact error (missing bluevk/BlueVK.h).
2. Investigate the v1.75.0 linux debug R2 artifact — where it comes
   from, whether it is genuinely missing the header or the download is
   incomplete/corrupted.
3. Fix it, evaluating the options in the ticket (patch header from
   release artifact / re-fetch / tolerate in hook / bump-pin version).
   Pick the safest fix that works for other machines too (do NOT rely on
   local state).
4. Verify: `scripts/build_linux.sh --debug` completes and the debug
   `.so` links clean (ldd -r). Also confirm the release build still
   works (the-0rkw hook changes are on asb/optional-libs-proposal — if
   that branch's hook is not merged, build against the current branch's
   hook and note the interaction).
5. Report: root cause, the fix, verification output.

### Rules

- Update this ticket with tk: start the-c8d3 when you begin, close when
  done (tk may not be installed — edit the status field directly).
- Commit all work locally on the asb/ branch.
- Push + open a PR when finished (if git push is blocked, commit and
  report — the main agent will push).
- Never merge the PR. Never commit or push directly to master/develop.
- Simplified technical English: short sentences, plain words.

## Resolution (2026-08-14, asb/linux-debug-artifact)

### Root cause

The download was NOT corrupted. The debug zip itself is missing the
headers. `scripts/build_linux.sh`'s debug block copied the bluevk
headers to `$TARGET_RELEASE_DIR/include/` instead of
`$TARGET_DEBUG_DIR/include/` (copy-paste typo). So the debug zip ships
`libbluevk.a` but no `bluevk/`, `vulkan/`, or `vk_video/` headers, and
the release zip just got them twice.

Verified by downloading both R2 zips and diffing their `include/`
trees: the debug zip is missing exactly the `libs/bluevk/include/`
tree. Reproduced the compile failure with clang against the extracted
debug include dir (`fatal error: 'bluevk/BlueVK.h' file not found`).

Same typo existed in the debug blocks of `build_macos.sh` and
`build_ios.sh` (Android was already correct). Fixed all three.

### Second bug found (masked by the first)

After the headers were fixed, Linux debug linking failed: `libmatdbg.a`
and `libfgviewer.a` both bundle civetweb, and the hook linked them
inside `-Wl,--whole-archive`, so every member of both was pulled in ->
"multiple definition of `mg_*`". Fixed in `hook/build.dart`: on Linux,
`matdbg`/`fgviewer` now link AFTER `--no-whole-archive` (normal archive
semantics pull only needed members; `libfilament.a` is whole-archived
so its references still resolve).

### Fix (2 parts)

1. `scripts/build_linux.sh` (+ macos/ios): debug block now copies
   bluevk headers to `$TARGET_DEBUG_DIR`. Future artifacts are correct.
2. `thermion_dart/hook/build.dart` (`getLibDir`): after extraction, if
   `include/bluevk/BlueVK.h` is missing, fetch the release zip of the
   same version/platform and merge `bluevk/`, `vulkan/`, `vk_video/`
   into the cache. Headers are build-mode-independent. Checked outside
   the success-token guard, so caches extracted from a broken zip heal
   too. No-op once artifacts are re-uploaded correctly. Skipped on iOS
   (never compiles vulkan sources). This makes existing machines work
   without waiting for an R2 re-upload.

NOTE for Nick: the v1.75.0 linux (x64 + arm64), macOS and iOS DEBUG
zips on R2 are still missing the bluevk headers. Rebuild/re-upload when
convenient (the hook repair covers users in the meantime; sandbox had
no R2 credentials so re-upload was not possible from here).

### Verification

- Reproduced original failure (missing `<bluevk/BlueVK.h>`), confirmed
  repair logs fire and build proceeds.
- `examples/dart/cli_headless` with `mode: debug` (aarch64 host,
  linux-arm64 debug artifact): hook compiles + links
  `libthermion_dart.so` (347 MB). `ldd -r` reports the same 48
  undefined symbols as the RELEASE build (png_*/mz_*/basisu encoder
  symbols, pre-existing, identical set in both modes — not a debug
  regression; both also behave the same under `dlopen` RTLD_NOW).
- Release build with the same modified hook: completes fine (bluevk
  repair is a no-op there).
- `dart analyze hook/build.dart`: clean. `flutter analyze`: 0 errors
  (51 pre-existing infos). `bash -n` on all three scripts: OK.
- Full `scripts/build_linux.sh --debug` (Filament from source) not run:
  no filament checkout in the sandbox. The script fix is the one-line
  target-dir correction; verified by inspection + parse.
- the-0rkw interaction: built against the current branch's hook (the
  asb/optional-libs-proposal hook is not merged here). The debug
  failure predates it and the fix is independent of `libraries:`
  placement.
- Example's own Dart code has pre-existing API drift errors
  (`FilamentApp.register`) unrelated to this ticket; the native build
  hook (the failing step) completes.

