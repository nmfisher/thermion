---
id: the-1ub8
status: closed
deps: []
links: []
created: 2026-08-09T10:30:00Z
type: task
priority: 1
assignee: Nick Fisher
tags: [ci, release]
---
# Simplify release: MANUAL-ONLY trigger, cuts the tag from develop

Design decision (from Nick, updated): releases are MANUAL ONLY. Pushes and
PRs to develop must NOT trigger a release — they only run normal CI
(Generate Artifacts: regen bindings + tests). The release is triggered by
hand (workflow_dispatch), and it cuts the tag from the DEVELOP branch tip.
Master is a legacy reference — leave it alone.

## Task (refinement of PR #227 — for the Claude session)

PR #227 currently auto-fires Create Release when Generate Artifacts completes
green on a develop push. Remove that auto path. The final design:

1. release.yml: REMOVE the `workflow_run` trigger (the auto path). The only
   trigger is `workflow_dispatch`.
2. release.yml check job: only acts on workflow_dispatch now. Simplify the
   `if:` condition accordingly (no workflow_run branch).
3. release.yml manual dispatch: version input OPTIONAL — when empty, read the
   version from the checked-out ref's pubspec. Default ref stays develop.
   The tag is created at the DEVELOP branch tip (resolve ref = develop).
   Keep the tag-not-exists and already-released checks exactly as they are.
4. docs/RELEASING.md: rewrite the runbook so releases are manual-only:
   - push/merge to develop = normal CI only, never a release
   - to release: run `gh workflow run "Create Release"` (or the GitHub UI
     dispatch button) with no version — it reads pubspec and tags develop tip
   - master documented as a legacy reference, not used for releases
5. Generate Artifacts stays as-is for develop pushes (normal CI: regen +
   tests) — it just no longer feeds a release chain.
6. Do not touch publish-pub-dev.yml or deploy.yml — they already work.

## Rules
- Update PR #227 (branch ci/release-from-develop) with these changes.
- Update the ticket with tk: tk start the-1ub8 when you begin, tk close the-1ub8 when done.
- Commit all work locally.
- Push your branch and keep the PR into develop updated.
- NEVER merge a PR yourself, and never commit or push directly to develop or master.
- Write in simplified technical English: short sentences, plain words, no jargon.


