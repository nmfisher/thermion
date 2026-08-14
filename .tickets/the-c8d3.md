---
id: the-c8d3
status: open
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
