---
id: the-f3wv
status: closed
deps: [the-k5p9]
links: []
created: 2026-08-10T05:10:00Z
type: bug
priority: 0
assignee: Nick Fisher
tags: [ci, release]
---
# Fix inputs.verify comparisons: boolean vs string type trap in generate-artifacts.yml

## Symptom
Release cycle for v0.5.0-pre.5 (Create Release run 31357040677 -> publish run
31357070941, head_sha 4fe518a3 which ALREADY contained the the-k5p9 guard).
"Verify generated artifacts / Generate Artifacts" STILL failed at
"Resolve post-push SHA" with the SAME error:

```
* tag v0.5.0-pre.5 -> FETCH_HEAD
fatal: ambiguous argument 'origin/v0.5.0-pre.5': unknown revision
exit code 128
```

The step RAN despite `if: inputs.verify != 'true'` being present.

## Root cause (verified)
The `verify` input is declared `type: boolean` and the caller passes
`with: verify: true` (a YAML boolean). GitHub Actions expressions do NOT
coerce booleans to strings in == / != comparisons (the falsy/truthy coercion
documented for expressions applies only to conditionals' truthiness, not to
equality between a boolean and the STRING 'true'). So:

- `inputs.verify != 'true'` with verify=true evaluates to TRUE -> steps that
  should be SKIPPED in verify mode actually RUN (this failure).
- `inputs.verify == 'true'` with verify=true evaluates to FALSE -> the
  "Fail if generated artifacts are stale (verify)" gate would NEVER fire on
  stale artifacts (silent gate bypass, not yet observed because artifacts
  were fresh, but equally broken).

ALL SIX occurrences in .github/workflows/generate-artifacts.yml are affected:
- L166  `if: inputs.verify == 'true' && steps.git-check.outputs.changed == 'true'`
- L173  `if: inputs.verify != 'true' && steps.git-check.outputs.changed == 'true'`
- L212  `if: inputs.verify != 'true' && steps.changes.outputs.native-changed == 'true' && (...)`
- L232  `if: inputs.verify != 'true' && steps.changes.outputs.native-changed == 'true' && (...)`
- L251  `if: inputs.verify != 'true'`  (Resolve post-push SHA)
- L264  `if: inputs.verify != 'true'`  (run-tests job)

## Fix
Replace ALL occurrences with truthiness comparisons (documented: falsy
false/0/""/null and truthy values coerce correctly in conditionals):

- `inputs.verify == 'true'` -> `inputs.verify`
- `inputs.verify != 'true'` -> `!inputs.verify`

Keep everything else byte-identical (same operators, same && chains, same
indentation). Verify with actionlint. Also grep to confirm ZERO remaining
`inputs.verify == 'true'` / `inputs.verify != 'true'` in the repo's workflows
(any other workflow with the same pattern needs the same fix).

## Rules
- ONLY .github/workflows/generate-artifacts.yml (plus the ticket file). If
  grep finds the broken pattern in OTHER workflows, mention it in the PR
  body but do NOT change them unless Nick approves.
- Raise a PR to develop. Set ticket status to closed.

## Context
Tag v0.5.0-pre.5 exists at 4fe518a3. After this PR merges, Nick deletes the
tag and re-creates it at the new tip, then re-dispatches. Expected next
obstacle (if any): the Test suite gate, which now runs against the
libc++-fixed R2 zips (PR #224) — hopefully green.
