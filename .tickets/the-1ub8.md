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
# Simplify release: develop is the release source, optional version reads from pubspec

Design decision (from Nick): develop is the main branch. PRs get raised
against develop, and releases are cut FROM develop. Master is just a legacy
reference — leave it alone, do not build on it; document it as legacy.

## Task (implementation — for the Claude session)

1. release.yml auto gate: currently fires only when Generate Artifacts
   completed successfully on a MASTER push. Change it so it fires when
   Generate Artifacts completes green on a DEVELOP push. (The check job's
   condition gates on github.event.workflow_run.head_branch == 'master' —
   flip to 'develop'.)
2. release.yml manual dispatch: make the version input OPTIONAL. When empty,
   read the version from the checked-out ref's pubspec (same code path as the
   workflow_run branch already uses). Default ref stays develop. Keep the
   tag-not-exists and already-released checks exactly as they are.
3. docs/RELEASING.md: rewrite the runbook so develop is the release source
   (bump version on develop → merge PR → release fires on develop push, or
   dispatch manually with no version to use pubspec's). Document master as a
   legacy reference that is no longer used for releases.
4. Do not touch publish-pub-dev.yml or deploy.yml — they already work.

## Rules
- Work on a fresh branch off origin/develop (NOT the current ci/release-on-merge branch).
- Update the ticket with tk: tk start the-1ub8 when you begin, tk close the-1ub8 when done.
- Commit all work locally.
- Push your branch and raise a PR into develop when finished.
- NEVER merge a PR yourself, and never commit or push directly to develop or master.
- Write in simplified technical English: short sentences, plain words, no jargon.


