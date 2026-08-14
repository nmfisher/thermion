---
id: the-33h6
status: open
deps: []
links: []
created: 2026-08-14T15:19:52Z
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

