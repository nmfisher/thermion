# Releasing to pub.dev

Releases of `thermion_dart` and `thermion_flutter` are published to pub.dev by
GitHub Actions using **OIDC automated publishing** — there are no long-lived
secrets to manage (the only secret is a fine-grained PAT used to create the
release tag; see below). Release tags are **created by CI, not by hand**: you
dispatch the `Create Release` workflow with the version, and it regenerates
bindings as a verify gate, runs the test suite, and only then creates and
pushes the `v<version>` tag. The tag push triggers the publish workflow, which
validates, waits for a manual approval, and publishes both packages in
dependency order.

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
2. Repository access: `nmfisher/thermion` only. Permissions: **Contents →
   Read and write**.
3. Add the token as a repo secret named **`RELEASE_TOKEN`**
   (Settings → Secrets and variables → Actions).

---

## Per-release flow

Cut releases from a green `develop` (the `Dart/Flutter Tests and Example Apps`
and `Generate Artifacts` workflows should be passing).

1. **Bump the version** in **both** pubspecs to the same value:
   - `thermion_dart/pubspec.yaml`
   - `thermion_flutter/thermion_flutter/pubspec.yaml`

   Pre-release versions are fine on pub.dev (e.g. `0.5.0-pre`, `0.7.0-pre`).

2. **Add a changelog entry** — prepend a `## <version>` section to **both**:
   - `thermion_dart/CHANGELOG.md`
   - `thermion_flutter/thermion_flutter/CHANGELOG.md`

   (The changelog is shared content; keep the two files in sync.)

3. **Ensure generated bindings are committed.** The `Generate Artifacts`
   workflow regenerates bindings on every `develop` push and commits any diff.
   If you changed anything under `thermion_dart/native/**`, wait for that
   workflow to finish (or run `make bindings` locally and commit).

4. **Dispatch `Create Release`** — **Actions → Create Release → Run workflow**,
   with:
   - `version`: the version to release, e.g. `0.5.0-pre.1` (no leading `v`)
   - `ref`: `develop` (default)

The workflow validates the version against both pubspecs, verifies the generated
bindings are committed (fails the release if stale), runs the full test suite,
and — only if everything is green — creates and pushes the `v<version>` tag,
which triggers the publish and deploy workflows. **Do not push tags by hand.**

### What CI does

The `Create Release` workflow (`.github/workflows/release.yml`) runs:

1. **`validate`** — checks the version format, that both pubspec versions match
   the requested version, and that the tag doesn't already exist.
2. **`verify-artifacts` / `verify-swift-bindings`** — regenerate the dart FFI/JS
   and swift bindings and **fail if they differ from what's committed** (stale
   bindings abort the release; run `make bindings` / `make flutter-bindings`,
   commit on develop, and re-dispatch).
3. **`tests`** — the full dart + flutter-build matrix.
4. **`tag`** — creates an annotated `v<version>` tag and pushes it with the
   `RELEASE_TOKEN` PAT.

The tag push then fires the `Publish to pub.dev` workflow
(`.github/workflows/publish-pub-dev.yml`), which re-runs the same gates and:

1. **`validate`** — checks the two pubspec versions match each other and the tag,
   confirms the version isn't already on pub.dev, then runs
   `pub publish --dry-run` on both packages (catches missing README/LICENSE,
   pana issues, bad file inclusion).

2. **`publish`** (behind the `pub.dev` environment approval):
   - publishes `thermion_dart` with `dart pub publish --force`,
   - polls pub.dev until `thermion_dart@<version>` is resolvable,
   - publishes `thermion_flutter` with `flutter pub publish --force`.

If a tag is pushed for a version that is already fully published, `validate`
short-circuits with "nothing to do", so re-running a release is safe and
idempotent.

### Pre-flight without publishing

To check publishability without cutting a release, run the workflow manually:
**Actions → Publish to pub.dev → Run workflow**. A manual dispatch runs only the
`validate` (dry-run) job — it never publishes. (Note: a manual dispatch of
`Create Release` DOES cut a release — that's its purpose.)

---

## Notes

- The workflow does **not** edit versions or changelogs. Bump them in the release
  commit, then tag.
- `thermion_flutter/thermion_flutter/pubspec_overrides.yaml` points
  `thermion_dart` at a local path for development. Only `pubspec.yaml` is
  uploaded when publishing, so the override never reaches pub.dev; it just lets
  `thermion_flutter` resolve locally during the dry-run/publish step.
- Native Filament binaries are **not** bundled in the published packages. Each
  package's build hook downloads them (from the project's R2 bucket) at consumer
  build time. See `thermion_dart/BUILDING.md`.
- The tag pattern `v[0-9]+.[0-9]+.[0-9]+*` matches `v0.5.0`, `v0.7.0-pre`, etc.
- If a release fails after the tag was already created, delete the tag
  (`git push origin :refs/tags/v<version>`), fix, and re-dispatch. Pushing a
  tag for an already-published version is a safe no-op.
