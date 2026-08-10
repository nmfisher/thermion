---
id: the-rrd3
status: in_progress
deps: []
links: []
created: 2026-08-10T01:40:00Z
type: bug
priority: 0
assignee: Nick Fisher
tags: [ci, release]
---
# Fix release tag push: unset checkout extraheader so RELEASE_TOKEN PAT is used

## Symptom
Create Release (manual dispatch) fails at "Create and push annotated tag":
`remote: Permission to nmfisher/thermion.git denied to github-actions[bot].`
403, exit 128. Happens even after regenerating RELEASE_TOKEN with
Contents + Actions write.

## Root cause (verified)
- actions/checkout@v4 (default persist-credentials: true) writes the
  GITHUB_TOKEN as `http.https://github.com/.extraheader` in the repo config.
- `git push "https://x-access-token:${RELEASE_TOKEN}@github.com/..."` sends
  both credentials; the persisted extraheader (bot token) WINS over the
  URL-embedded PAT. Server sees github-actions[bot], not the PAT.
- Old workflow had `permissions: contents: write`, so even the bot token
  could push (worked Aug 8). PR #225/#227 tightened permissions to
  `contents: read` + `actions: read`, so the effective push credential is
  read-only → 403. Regenerating the PAT does not help because the PAT is
  never actually used.

## Task (implementation — for the Claude session)
1. In `.github/workflows/release.yml`, "Create and push annotated tag" step,
   BEFORE the `git push`, add:
   `git config --unset-all http.https://github.com/.extraheader || true`
   (with a short comment explaining why: checkout persists the GITHUB_TOKEN
   extraheader which overrides the URL PAT).
2. Keep everything else unchanged. Do NOT touch other workflows.
3. Commit on a branch, push, open a PR into develop (or update the existing
   open PR if the session prefers and it is still open). NEVER merge.

## Rules
- Update the ticket with tk: tk start the-rrd3 when you begin, tk close
  the-rrd3 when done. If tk is unavailable, edit the frontmatter directly.
- Commit all work locally.
- Push your branch and raise/update a PR into develop when finished.
- NEVER merge a PR yourself, and never commit or push directly to develop or
  master.
- Write in simplified technical English: short sentences, plain words, no
  jargon.


