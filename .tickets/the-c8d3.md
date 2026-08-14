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
