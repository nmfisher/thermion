---
id: the-4a2k
status: in_progress
deps: [the-upl0]
links: []
created: 2026-08-10T03:30:00Z
type: task
priority: 1
assignee: Nick Fisher
tags: [ci, release, pub-dev]
---
# Fix pub.dev dry-run warnings that block the publish validate gate

## Symptom
Create Release run 31352461521 succeeded (tag v0.5.0-pre.5 pushed at new tip
2ce1c4b2). The tag fired "Publish to pub.dev" (run 31352486065) which now
STARTS correctly (permissions fix worked), but the `Validate (dry-run)` job
fails at `Dry-run publish (thermion_dart)` with exit code 65:

> Package validation found the following 2 potential issues:
> * Your dependency on "ffigen_js" should allow more than one version.
>   For example: dependencies: ffigen_js: ^0.0.14-pre
> * thermion_dart/CHANGELOG.md doesn't mention current version (0.5.0-pre.5).

## Task
Two small fixes:

1. thermion_dart/pubspec.yaml line 24: change
   `ffigen_js: 0.0.14-pre` -> `ffigen_js: ^0.0.14-pre`
   (loosen the constraint so it allows more than one version).

2. thermion_dart/CHANGELOG.md: add a `## 0.5.0-pre.5` entry at the top (above
   the existing `## 0.5.0-pre.2` section) with brief notes. The top of the file
   has a comment line: `> Shared changelog for thermion_dart and
   thermion_flutter (released in lockstep).` Keep that comment at the very top.
   Content can be short — this is a pre-release. Suggested notes: the CI
   release pipeline was reworked (release-from-develop, manual trigger) and
   publish gates were added. Keep it honest and brief.

## Rules
- ONLY these two files. Do not touch workflows, versions, or anything else.
- Verify after the change: `dart pub publish --dry-run` is NOT needed — just
  confirm the pubspec parses (`dart pub get` not required either). A grep for
  `^  ffigen_js: \^0.0.14-pre` and the new changelog heading is enough.
- Raise a PR to develop when done. Set ticket status to closed.

## Context
Tag v0.5.0-pre.5 already exists on origin at tip 2ce1c4b2. After this PR
merges, the tag must be deleted and re-created (or a new version bumped) for
the publish workflow to see the fixed files — Nick handles that step.
