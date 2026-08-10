---
id: the-upl0
status: in_progress
deps: [the-rrd3]
links: []
created: 2026-08-10T02:58:04Z
type: bug
priority: 0
assignee: Nick Fisher
tags: [ci, release]
---
# Fix publish workflow permissions: called workflows need contents: write

## Symptom
Tag push v0.5.0-pre.5 fired "Publish to pub.dev" (run 31349225754) and it died
with `startup_failure` BEFORE any job ran. No jobs, no logs. The Deploy site
workflow on the SAME tag push succeeded, so tag triggers work in general.

## Root cause (verified from the run page annotation)
GitHub rejected the workflow file at startup:

> Invalid workflow file: .github/workflows/publish-pub-dev.yml#L133
> Error calling workflow 'generate-artifacts.yml@53f8b3cd'.
> The workflow is requesting 'contents: write', but is only allowed 'contents: read'.

publish-pub-dev.yml has a top-level `permissions:` block with `contents: read`
(plus `id-token: write` for the pub.dev OIDC step). Its reusable-workflow jobs
`generate-artifacts` and `generate-swift-bindings` call workflows that need
`contents: write` (they regenerate bindings and commit/push on non-verify
calls; even verify mode needs write in their declared permissions). GitHub
enforces that a called reusable workflow may not request MORE than the caller
allows, and rejects the whole file at parse/startup time.

## Fix
Widen the CALLER's top-level permissions so the called workflows are allowed:

```yaml
permissions:
  id-token: write   # pub.dev OIDC publish
  contents: write   # required by called generate-artifacts / generate-swift-bindings
  actions: read     # test/verify gates
```

Notes:
- Keep the change minimal: ONLY the permissions block in
  .github/workflows/publish-pub-dev.yml. Do not touch any other workflow.
- The publish job itself only reads + publishes via OIDC, but workflow-level
  permissions apply to the whole file, so `contents: write` at the top is the
  pragmatic fix. Do NOT try to scope per-job permissions unless trivial.
- After the fix, run actionlint on the file to confirm it still parses.
- Ticket state: set status to closed when done.

## Verification
The tag v0.5.0-pre.5 exists and no publish has happened for it yet. After the
PR is merged, Nick will re-dispatch or re-push a tag to test. The
generate-artifacts verify gate will run against the CURRENT R2 zips (still
libstdc++-broken for dart-tests), so a full green publish may still be blocked
by PR #224 (libc++ fix) — but the workflow should at least START and run jobs
instead of startup_failure.
