---
id: the-33h6
status: closed
deps: []
links: []
created: 2026-08-14T15:19:52Z
closed: 2026-08-15T00:00:00Z
type: feature
priority: 1
assignee: Nick Fisher
tags: [ci, build, materials, filament]
---
# CI: always regenerate .filamat materials when filament.version changes

Root cause (run 31808743800, dart-tests Linux): committed .filamat files were compiled with v1.74.0 matc (embedded MATERIAL_VERSION=74, see commit ff1fa11e). Filament v1.75.0 libs expect MATERIAL_VERSION=75 (libs/filabridge MaterialEnums.h). Loading a stale .filamat throws utils::PostconditionPanic 'Material version mismatch. Expected 75 but received 74' (filament/src/MaterialDefinition.cpp:230). Crash hit geometry_tests test 3 ('material with vertexDomain: view') - the first test to load examples/assets/viewspace.filamat. All earlier tests use runtime-compiled ubershader materials, so they passed. NOT related to threads or the lifetime-hardening commit 1f9f915e. Requirement: CI must ALWAYS regenerate materials when filament.version changes, so committed .filamat files can never go stale again.

## Design

matc/resgen source: Filament GitHub releases ship versioned tool tarballs (filament-v1.75.0-linux.tgz / -mac.tgz / -windows.tgz) containing bin/matc + resgen. Download the tarball matching the version in filament.version; cache per version. Trigger: compare filament.version against the version embedded in the committed .filamat headers (bytes 12-15, e.g. 0x4A=74), or always regenerate (matc output for a fixed version is deterministic). On diff: commit regenerated files automatically (or open a PR); never ship stale materials. Scope: materials/*.filamat (10 files) + resgen-embedded .c/.h in thermion_dart/native/include/material/ + examples/assets/{customattributes,solidcolor,viewspace}.filamat. NOTE: picking_index0.filamat is an unused stale leftover. IMMEDIATE FIX NEEDED NOW (independent of CI work): regenerate all .filamat + resgen outputs with v1.75.0 matc and commit, so the current branch builds and dart-tests pass again.

## Acceptance Criteria

1. Bumping filament.version automatically regenerates all committed .filamat files and embedded resgen resources in CI (committed or opened as a PR). 2. A version bump no longer requires manual material regeneration for tests/examples to pass. 3. The embedded material version always equals the MATERIAL_VERSION of the linked libs. 4. Dart tests (geometry_tests included) pass on the v1.75.0 branch after the immediate regeneration.

## Resolution (2026-08-15)

- `scripts/check-material-versions.sh`: cheap gate (no downloads) that reads the embedded MATERIAL_VERSION (LE u32 at byte 12) from every committed artifact (`examples/assets/*.filamat`, `thermion_dart/native/include/material/*.bin`) and compares it against the minor of filament.version. outline.bin is excluded: no .mat source exists and no native code references it (edge_outline is what TMaterialInstance.cpp uses); it is a stale leftover like picking_index0.filamat and a candidate for deletion in a follow-up.
- `scripts/regenerate-materials.sh`: downloads the versioned filament-v*-linux.tgz (matc+resgen) into a per-version cache, runs `make materials`, then verifies via the check script.
- `.github/workflows/regenerate-materials.yml`: runs on every push to any branch except develop (and non-develop PRs, dispatch). NOT path-filtered - always regenerates and commits the diff, so pre-existing stale state is healed on the next push and a version bump can never ship stale materials (matc output is deterministic for a fixed version). develop stays with generate-artifacts.yml to keep a single pusher per branch.
- `generate-artifacts.yml`: the materials-changed paths filter is now OR'd with the stale check (runs unconditionally), so a stale-with-no-path-change state on develop also triggers regeneration + commit; the download/compile steps now reuse the shared regen script and a tools cache. The release verify gate therefore also catches stale materials.
- `run-dart-tests.yml`: runs the check right after checkout so a stale tree fails fast with a clear message instead of a PostconditionPanic deep in a test.
- `materials/build.sh`: capture_uv added to the regeneration loop (it has a .mat source and committed artifacts, but was never regenerated).
- The immediate v1.75.0 regeneration of the committed artifacts was intentionally left to the new workflow (first push/PR of this branch), which commits it automatically.



## Result (2026-08-15, PR 237 reworked)

Done per the update request. The branch was rebuilt from develop so the PR diff contains only the CI work:

- scripts/check-material-versions.sh is gone. No version-comparison logic anywhere.
- Regeneration rule: regenerate-materials.yml fires only when filament.version changes (GitHub paths filter). When the version did not change, the workflow never starts (fast no-op). It downloads matc/resgen from the version-matched Filament release tarball (cached per version), runs scripts/regenerate-materials.sh (shared script: download + make materials), and commits regenerated materials to the branch. develop is excluded; generate-artifacts.yml owns develop and its materials-changed filter now covers filament.version.
- All regenerated materials and unrelated changes (build.dart, .g.dart bindings, input handler tests, CI-generated commits) are off the branch. No .filamat or generated material file is touched by this branch.
- PR 237 retargeted to develop, branch force-pushed, description updated.
