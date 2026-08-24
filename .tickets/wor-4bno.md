---
id: wor-4bno
status: in_progress
deps: []
links: []
created: 2026-08-24T09:38:41Z
type: chore
priority: 2
assignee: Nick Fisher
tags: [build, native, binary-size]
---
# Remove verified-unused native library link inputs

Remove imageio, tinyexr, and filameshio from production link inputs after Linux archive ordering is fixed. Retain filamat, z, zstd, png, and all rendering/image-decoding libraries.

## Acceptance Criteria

Dart and Flutter CI pass on Linux, macOS, and Windows; Web and Android build; Linux has no unresolved symbols; the PR is stacked separately from the Linux linker fix.


## Notes

**2026-08-24T09:46:21Z**

Source audit found no production wrapper references to imageio, tinyexr, or filameshio. Artifact build scripts and native-only test CMake files remain unchanged. Validation: Dart hook analysis passed; thermion_flutter analysis passed; Flutter Web quickstart built; macOS asset and image tests passed (11 tests), including PNG background decoding and KTX loading.
