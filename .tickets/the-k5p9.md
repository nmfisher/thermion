---
id: the-k5p9
status: in_progress
deps: [the-4a2k]
links: []
created: 2026-08-10T04:40:00Z
type: bug
priority: 0
assignee: Nick Fisher
tags: [ci, release]
---
# Fix generate-artifacts "Resolve post-push SHA" step failing on tag refs

## Symptom
Release cycle for v0.5.0-pre.5 (Create Release run 31355291579 -> publish run
31355323861). Validate (dry-run) PASSED, Verify swift bindings PASSED, but
"Verify generated artifacts / Generate Artifacts" failed in 37s at the
"Resolve post-push SHA" step:

```
From https://github.com/nmfisher/thermion
 * tag               v0.5.0-pre.5 -> FETCH_HEAD
fatal: ambiguous argument 'origin/v0.5.0-pre.5': unknown revision or path not in the working tree.
exit code 128
```

## Root cause
In .github/workflows/generate-artifacts.yml the step sets
`PUSH_BRANCH: ${{ github.head_ref || github.ref_name }}`. On a tag push
`github.ref_name` is the TAG name (`v0.5.0-pre.5`). The step fetches it
(successful — the tag is fetched), then runs `git rev-parse origin/$PUSH_BRANCH`
which expects a BRANCH ref (`origin/v0.5.0-pre.5`). Tags never create an
`origin/<name>` branch ref, so rev-parse fails.

Also, in verify mode (the release gate), this step is useless: its only
consumer is the run-tests job (`ref: ${{ needs.generate-artifacts.outputs.sha }}`),
and run-tests is already skipped when `inputs.verify == 'true'`. Non-verify
runs always happen on a branch (develop push / PR head / manual dispatch),
never on a tag.

## Fix
ONE condition added to the step in .github/workflows/generate-artifacts.yml:

```yaml
      - name: Resolve post-push SHA
        if: inputs.verify != 'true'
        id: resolve-sha
        ...
```

(The job output `sha:` stays declared — it is simply empty in verify mode,
and nothing consumes it there.)

## Rules
- ONLY that one `if:` line in generate-artifacts.yml. No other files, no
  other changes, no reformatting.
- Run actionlint on the file to confirm it parses.
- Raise a PR to develop. Set ticket status to closed.

## Context
Tag v0.5.0-pre.5 currently exists at tip c2adc629 (#230 merged). After this
PR merges, the tag must be deleted and re-created at the new tip (Nick does
that). The next cycle should then reach: validate -> verify gates -> tests
(dart tests now run against the libc++-fixed R2 zips) -> publish approval.
