---
id: wor-qmis
status: in_progress
deps: []
links: []
created: 2026-08-24T09:21:30Z
type: bug
priority: 1
assignee: Nick Fisher
tags: [build, linux, linker]
---
# Fix Linux static archive ordering without cross-platform link changes

Replace Linux whole-archive linking with correctly ordered static archives while retaining the full library list and leaving every non-Linux build path unchanged.

## Acceptance Criteria

Linux debug and release load with no unresolved symbols; rendering tests pass; non-Linux hook behavior is unchanged; controlled size comparison is recorded.


## Notes

**2026-08-24T09:36:26Z**

Implementation retains the complete library list and moves only Linux archives after object files via CBuilder.libraries. Added -Wl,-z,defs so unresolved Linux symbols fail during linking. Dart hook analysis and thermion_flutter analysis pass. Local ARM64 container exited before invoking the Dart build hook, so GitHub Linux CI is the authoritative native validation.

**2026-08-24T09:45:54Z**

First CI run exposed libm as an implicit Linux dependency once -Wl,-z,defs was enabled: math symbols from Thermion, Filament, basis_transcoder, geometry, matdbg, and filamat were unresolved. Added m after all static archives so the shared library records its dependency explicitly rather than relying on the host process.
