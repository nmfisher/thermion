import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Astro (and any build tooling) always runs with the docs/ directory as the
// working directory — pnpm sets cwd to the package root, and CI does the same.
// resolve() from process.cwd() therefore anchors at docs/ regardless of how the
// module is bundled. (import.meta.url-based paths break under Vite bundling.)
const repoRoot = resolve(process.cwd(), '..');

/**
 * Read the Thermion release version (e.g. "0.6.1") for display in the docs.
 *
 * `thermion_dart/pubspec.yaml` is the single source of truth — it is the
 * version the release workflow tags and publishes, and `thermion_flutter` is
 * released in lockstep with it (see docs/RELEASING.md).
 *
 * A `THERMION_VERSION` environment variable overrides this, which the deploy
 * workflow sets from the same pubspec so tag builds and manual dispatches stay
 * consistent with what the gallery WASM badge shows.
 */
export function getProjectVersion(): string {
  const fromEnv = process.env.THERMION_VERSION;
  if (fromEnv) return fromEnv.trim();

  try {
    const pubspec = readFileSync(
      resolve(repoRoot, 'thermion_dart/pubspec.yaml'),
      'utf8',
    );
    const match = pubspec.match(/^version:\s*(.+)$/m);
    if (match) return match[1].trim();
  } catch {
    // fall through
  }
  return 'dev';
}

/** The Filament release bundled with the documented Thermion version. */
export function getFilamentVersion(): string {
  try {
    const contents = readFileSync(
      resolve(repoRoot, 'filament.version'),
      'utf8',
    );
    const version = contents.trim().split(/\s+/).pop();
    if (version) return version;
  } catch {
    // fall through
  }
  return '';
}
