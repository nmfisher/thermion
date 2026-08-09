# Releasing to pub.dev

Releases of `thermion_dart` and `thermion_flutter` are published to pub.dev by
GitHub Actions using **OIDC automated publishing** — there are no long-lived
secrets to manage (the only secret is a fine-grained PAT used to create the
release tag; see below).

**The release pathway has a single trigger: merging to `master`.** `develop` is
the integration branch; `master` is the release branch. Merge a version-bump PR
to `develop`, then merge `develop` into `master`, and CI does everything: it
regenerates artifacts, runs the test suite, creates the `v<version>` tag, waits
for your approval, and publishes both packages — plus the docs site.

The two packages are released **in lockstep**: they always share the same
version number and ship together. `thermion_flutter` depends on `thermion_dart`,
so `thermion_dart` is published first and confirmed live before
`thermion_flutter` follows.

---

## One-time setup

Do these once before the first release.

### 1. Enable GitHub Actions publishing on pub.dev (per package)

For **each** package:

1. Open `https://pub.dev/packages/<package>/admin`
   - `https://pub.dev/packages/thermion_dart/admin`
   - `https://pub.dev/packages/thermion_flutter/admin`
2. Under **Automated publishing**, click **Enable publishing from GitHub
   Actions**.
3. Set the repository to `nmfisher/thermion` and the tag pattern to
   `v{{version}}`.

This tells pub.dev to trust OIDC tokens minted by GitHub Actions **only** when a
tag matching `v{{version}}` is pushed and the tag's version equals the version in
`pubspec.yaml`.

### 2. Create the `pub.dev` GitHub Environment

1. Repo **Settings → Environments → New environment**, name it `pub.dev`.
2. Add **Required reviewers** — the maintainers who must approve a release.

The `publish` job in `.github/workflows/publish-pub-dev.yml` targets this
environment, so nothing is published until a reviewer clicks approve.

### 3. Create the `RELEASE_TOKEN` repo secret

The `Create Release` workflow pushes the release tag. It must use a PAT, not
`GITHUB_TOKEN` — GitHub suppresses workflow triggers caused by `GITHUB_TOKEN`
pushes, so a `GITHUB_TOKEN` tag push would never fire the publish/deploy
workflows.

1. GitHub → **Settings → Developer settings → Fine-grained tokens → Generate
   new token**.
2. Repository access: `nmfisher/thermion` only. Permissions:
   - **Contents → Read and write**
   - **Actions → Read and write** ⚠️ — this second permission is required:
     a Contents-only PAT pushes the tag silently but **fires zero workflows**,
     so the release would never publish.
3. Add the token as a repo secret named **`RELEASE_TOKEN`**
   (Settings → Secrets and variables → Actions).

---

## Per-release flow

1. **Bump the version** in **both** pubspecs to the same value:
   - `thermion_dart/pubspec.yaml`
   - `thermion_flutter/thermion_flutter/pubspec.yaml`

   Pre-release versions are fine on pub.dev (e.g. `0.5.0-pre`, `0.7.0-pre`).

2. **Add a changelog entry** — prepend a `## <version>` section to **both**:
   - `thermion_dart/CHANGELOG.md`
   - `thermion_flutter/thermion_flutter/CHANGELOG.md`

   (The changelog is shared content; keep the two files in sync.)

3. **Merge the PR to `develop`** and wait for the `Generate Artifacts` workflow
   to finish (it regenerates bindings on every develop push and commits any
   diff; it also runs the test suite). Do not proceed while it is red.

4. **Merge `develop` into `master`.** That single merge is the release. You can
   merge via a PR (`develop` → `master`) or a fast-forward merge locally.

That's it — everything below happens automatically.

### What CI does

The merge to `master` fires `Generate Artifacts` (push trigger), which
regenerates + commits bindings and runs the full test matrix at the post-push
tip. When that run **completes successfully**, the `Create Release` workflow
(`.github/workflows/release.yml`, `workflow_run` trigger) takes over:

1. **`check`** — reads the version from the merged commit's pubspec. If
   `v<version>` is already tagged **and** the release actually completed
   (versions live on pub.dev or a successful publish run exists), the chain
   stops: the push did not cut a new release. If the tag exists but the release
   **never** completed (a *stuck tag*), the chain **fails** with instructions —
   see [Stuck tags](#stuck-tags) below.
2. **`validate`** — checks the version format, that both pubspec versions match
   the version, and that the tag doesn't already exist.
3. **`wait-swift`** — only when the merge also regenerated Swift bindings:
   waits for that run to finish so the tag includes them.
4. **`tag`** — resolves the current `master` tip (which includes any
   regenerated bindings), re-verifies the version, and pushes an annotated
   `v<version>` tag with the `RELEASE_TOKEN` PAT.
5. **`watch-release`** — verifies the tag push actually fired the publish and
   deploy workflows (fails within ~5 minutes if it didn't — almost always a
   PAT permission problem), waits for the deploy, and reports the publish URL,
   stopping early once the publish is waiting for your approval.

The tag push then fires the `Publish to pub.dev` workflow
(`.github/workflows/publish-pub-dev.yml`), which re-runs the gates and:

1. **`validate`** — checks the two pubspec versions match each other and the tag,
   confirms the version isn't already on pub.dev, then runs
   `pub publish --dry-run` on both packages (catches missing README/LICENSE,
   pana issues, bad file inclusion).
2. **`verify-artifacts` / `verify-swift-bindings`** — regenerate the dart FFI/JS
   and swift bindings at the tag and **fail if they differ from what's
   committed** (stale bindings abort the release).
3. **`tests`** — the full dart + flutter-build matrix.
4. **`publish`** (behind the `pub.dev` environment approval):
   - publishes `thermion_dart` with `dart pub publish --force`,
   - polls pub.dev until `thermion_dart@<version>` is resolvable,
   - publishes `thermion_flutter` with `flutter pub publish --force`.

The same tag push fires **`Deploy site`** (`.github/workflows/deploy.yml`),
which builds the docs site + WASM gallery and deploys them to Cloudflare Pages
(thermion.dev).

If a tag is pushed for a version that is already fully published, `validate`
short-circuits with "nothing to do", so re-running a release is safe and
idempotent.

### Stuck tags

A tag can exist without the release ever happening (e.g. the tag was pushed
while `RELEASE_TOKEN` had the wrong permissions, so no publish run fired).
The `Create Release` `check` job detects this and **fails loudly** instead of
silently skipping. To recover:

1. Fix the `RELEASE_TOKEN` PAT (add **Actions → Read and write**), **or**
2. delete the stuck tag — `git push origin :refs/tags/v<version>` — and merge
   again (or bump the version instead), **or**
3. if the version is published and only the tag is missing, push the tag by
   hand: `git push origin v<version>` (it must match the pubspec version).

### Manual fallback

To release a specific version from a specific ref without the merge-to-master
trigger (e.g. after a failed release), dispatch **Actions → Create Release →
Run workflow** with `version` and `ref` (default `develop`). It runs the same
`validate → wait-swift → tag → watch-release` chain and still publishes via the
tag push. **Do not push tags by hand** — the tag must point at a commit whose
bindings are committed and whose tests passed.

### Pre-flight without publishing

To check publishability without cutting a release, run the workflow manually:
**Actions → Publish to pub.dev → Run workflow**. A manual dispatch runs only the
`validate` (dry-run) job — it never publishes.

---

## Notes

- The workflow does **not** edit versions or changelogs. Bump them in the
  release PR, then merge.
- `thermion_flutter/thermion_flutter/pubspec_overrides.yaml` points
  `thermion_dart` at a local path for development. Only `pubspec.yaml` is
  uploaded when publishing, so the override never reaches pub.dev; it just lets
  `thermion_flutter` resolve locally during the dry-run/publish step.
- Native Filament binaries are **not** bundled in the published packages. Each
  package's build hook downloads them (from the project's R2 bucket) at consumer
  build time. See `thermion_dart/BUILDING.md`.
- The tag pattern `v[0-9]+.[0-9]+.[0-9]+*` matches `v0.5.0`, `v0.7.0-pre`, etc.
- The generator workflows push with `GITHUB_TOKEN` on purpose: it fires no
  follow-up runs (no loops). Do not upgrade those push credentials — the
  `web.version` file always differs and would loop forever.
