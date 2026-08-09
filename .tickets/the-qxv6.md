---
id: the-qxv6
status: in_progress
deps: []
links: []
created: 2026-08-09T02:23:19Z
type: bug
priority: 1
assignee: Nick Fisher
tags: [ci, linux, release, native]
---
# Investigate: Create Release fails — libthermion_dart.so undefined symbol std::endl on Linux

Create Release workflow fails at Dart Tests (Linux): every test file fails to load libthermion_dart.so with 'undefined symbol: _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_' (std::endl). Reproduces without concurrent Build Filament (runs 31257368205, 31289266607). Same commit passes on Windows dart tests and all flutter builds. Hook links with -stdlib=libc++ AND -l stdc++ (native_toolchain_c default). Need root-cause analysis + proposed fix. PROPOSAL-ONLY: no code changes.

## Investigation brief (for the sandbox agent — GLM, proposal-only)

You are a coding agent investigating a CI failure in the thermion repo. Your job: find the root cause and write a proposal document. DO NOT change code or tests. Analysis and proposal only.

### Context
The GitHub Actions workflow "Create Release" fails. The failing job is "Test suite / dart-tests / Dart Tests (Linux)". All 18 Dart test files fail to LOAD. The error is:

Failed to load dynamic library '.../libthermion_dart.so': undefined symbol: _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_

The symbol is the mangled name of std::endl<char, char_traits<char>>(basic_ostream<char, char_traits<char>>&). It is a C++ standard library symbol. This is a C++ ABI / standard library mismatch.

The same commit passes:
- Dart Tests (Windows) in the same run
- Flutter Examples (macOS, Linux, Windows)
- The verify job "dart-tests Dart Tests (Linux)" at 13:10 on Aug 8 (104 tests passed)

It failed:
- "Test suite dart-tests Dart Tests (Linux)" at 13:36 on Aug 8 (same release run, same commit 697e37c)
- Again today (run 31289266607, commit e1201fd1), with NO concurrent Build Filament run. So it is NOT a race.

### Evidence already gathered (verify it yourself)
1. The build hook thermion_dart/hook/build.dart builds libthermion_dart.so. For non-Windows it adds the flag '-stdlib=libc++' (line ~229).
2. native_toolchain_c (version 0.17.6, in ~/.pub-cache) adds its own C++ stdlib link flag. Its Linux default is 'stdc++' (file lib/src/cbuilder/run_cbuilder.dart, map defaultCppLinkStdLib). The hook only sets cppLinkStdLib for Android ('c++_static'); for Linux it stays null, so native_toolchain_c links '-l stdc++'.
3. So the actual clang command (from build.log artifact 'build-logs-dart-Linux' of run 31257368205) mixes: -l stdc++ AND -stdlib=libc++. That is a libstdc++ vs libc++ ABI mismatch.
4. The test job appends hooks.user_defines.thermion_dart.mode: debug to pubspec.yaml (see run-dart-tests.yml), so the debug Filament libs and a debug build are used.
5. LD_LIBRARY_PATH is set to the cached LLVM 16 lib dir. The job also apt-installs libc++-dev and libc++abi-dev (version 14.0).
6. The failing .so is at .dart_tool/lib/libthermion_dart.so after the build hook runs during dart pub get.

### Investigation tasks
1. Reproduce the native build in this container if the toolchain allows (clang, LLVM 16, Filament libs download). If not, reason precisely from the link line.
2. Determine which C++ standard library the .so needs at runtime, and why std::endl is undefined. Check: extern-template in libc++ headers, DT_NEEDED entries missing libc++.so.1, or --as-needed dropping libstdc++.
3. Explain why it is flaky: same commit passed at 13:10 but failed at 13:36, and fails today. Look for what changes between runs: runner image, apt package versions, LLVM cache contents, pub cache contents.
4. Write a PROPOSAL document with the recommended fix, at exact file/line level. Consider options: set cppLinkStdLib to 'c++' on Linux in hook/build.dart, drop '-stdlib=libc++', or add explicit '-lc++'. Weigh them and recommend one.

### Deliverable
- Write your findings and proposed fix to: docs/release-failure-analysis.md (create the file; docs/ exists).
- Add a short summary to the ticket file .tickets/the-qxv6.md.

### Rules
- PROPOSAL ONLY. Do not modify code, tests, or CI workflows. Analysis and a proposal document only.
- Update ticket status with the tk CLI: tk start the-qxv6 when you begin, tk close the-qxv6 when done.
- Commit all work locally on your branch.
- When finished, push your branch and open a PR. You may ONLY push your own branch and open a PR. NEVER merge a PR. NEVER commit or push to main or master.
- Use gh CLI to download any workflow logs you need (for example: gh run view 31289266607 --log-failed).
- Write in simplified technical English: short sentences, plain words, no jargon.

## Implementation task (follow-up, same branch/volume asb/release-failure-inv)

The proposal was reviewed. The long-term fix is accepted: make the Filament
Linux prebuilts single-stdlib. Implement it now. This is NOT proposal-only
anymore — code changes are allowed, but ONLY in the Filament Linux build
scripts (and docs/ticket files). Do NOT touch thermion_dart/hook/build.dart,
CI workflow YAML, or app code unless the analysis shows it is required.

### Task
Update the Filament Linux build scripts so `libimageio` and `libtinyexr`
compile with libc++ (`-stdlib=libc++`) instead of the default libstdc++.

### Where
- `scripts/build_linux.sh`, function `build_third_party_libs()` (lines ~173-215).
  Two cmake invocations build the affected libs:
  - imageio: `-DCMAKE_CXX_FLAGS=...` (line ~189)
  - tinyexr: `-DCMAKE_CXX_FLAGS=...` (line ~204)
  The script sets `export CXX=clang++` (line ~171) but never passes
  `-stdlib=libc++`, so clang defaults to libstdc++ — which is exactly why the
  archives end up as libstdc++ ABI.
- Check whether the arm64 path uses the same script (`build-linux-arm64` job in
  `.github/workflows/build-filament.yml` runs `scripts/build_linux.sh`) — if
  so, one change covers both. If there is a separate arm64 script, update it
  too.

### What to do
1. Add `-stdlib=libc++` to the `CMAKE_CXX_FLAGS` of BOTH cmake invocations
   (imageio and tinyexr). Keep all existing warning-suppression flags and
   include paths. The function builds both Debug and Release — cover both.
2. Verify the change actually produces libc++-ABI archives. A full 50-minute
   Filament build is NOT required. Minimal verification is enough:
   - compile one tinyexr/imageio translation unit with the new flags and check
     the object references `std::__1::*` symbols (`nm`), or
   - run the imageio/tinyexr cmake+ninja steps standalone if the Filament
     source tree is available in the container; otherwise do the compile-flag
     check on a small repro file.
3. Update `docs/release-failure-analysis.md`: mark the long-term fix as
   implemented. Note that the fix only takes effect once a new `Build Filament`
   workflow run uploads rebuilt zips to R2 (the release CI downloads those
   zips; script changes alone do not change already-uploaded artifacts).
4. Update the ticket: status back to in_progress, add a resolution note when
   done.

### Deliverable
- Modified `scripts/build_linux.sh` (+ arm64 variant if one exists).
- Updated `docs/release-failure-analysis.md`.
- Updated ticket summary in `.tickets/the-qxv6.md`.
- Commit on the SAME branch (`asb/release-failure-inv`), push, and update the
  open PR #224. NEVER merge. NEVER push to main or master.

### Rules
- Update ticket status with tk if available (start when beginning, close when
  done); otherwise edit the frontmatter directly (as before — tk was not
  available in the sandbox).
- Commit all work locally on your branch.
- When finished, push your branch and open/update a PR. You may ONLY push your
  own branch and open a PR. NEVER merge a PR. NEVER commit or push to main or
  master.
- Write in simplified technical English: short sentences, plain words, no
  jargon.


