# Releasing to pub.dev

Releases of `thermion_dart` and `thermion_flutter` are published to pub.dev by
GitHub Actions using **OIDC automated publishing** — there are no long-lived
secrets to manage. A maintainer pushes a `v<version>` git tag; CI validates,
waits for a manual approval, and publishes both packages in dependency order.

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

3. **Commit to `develop`** and push.

4. **Tag and push the tag:**
   ```sh
   git tag v<version>     # e.g. git tag v0.5.0
   git push origin v<version>
   ```

That's it — pushing the tag triggers the workflow.

### What CI does

The `Publish to pub.dev` workflow (`.github/workflows/publish-pub-dev.yml`) runs
two jobs:

1. **`validate`** — checks the two pubspec versions match each other and the tag,
   confirms the version isn't already on pub.dev, then runs
   `pub publish --dry-run` on both packages (catches missing README/LICENSE,
   pana issues, bad file inclusion).

2. **`publish`** (only on a tag push, behind the `pub.dev` environment approval):
   - publishes `thermion_dart` with `dart pub publish --force`,
   - polls pub.dev until `thermion_dart@<version>` is resolvable,
   - publishes `thermion_flutter` with `flutter pub publish --force`.

If a tag is pushed for a version that is already fully published, `validate`
short-circuits with "nothing to do", so re-running a tag is safe and idempotent.

### Pre-flight without publishing

To check publishability without cutting a release, run the workflow manually:
**Actions → Publish to pub.dev → Run workflow**. A manual dispatch runs only the
`validate` (dry-run) job — it never publishes.

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
