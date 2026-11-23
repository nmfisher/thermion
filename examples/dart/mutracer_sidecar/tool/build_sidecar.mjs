#!/usr/bin/env node
// Bundle the JS sidecar (js/mutracer_sidecar.js) into web/ for the browser.
//
// Two esbuild passes:
//  1. MuTracer's BVH worker (referenced via `new Worker(new URL(...))` inside
//     the library) as web/bvh.worker.js, so the URL resolves at runtime.
//  2. The sidecar entry as web/mutracer_sidecar.bundle.js, code-split so the
//     optional passes (denoisers, caustics, WebGL fallback) load lazily.
//
// Run via `npm run build` (see package.json).
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const mutracerLib = path.dirname(
  fileURLToPath(import.meta.resolve('@meimu/mutracer')));

await build({
  entryPoints: [path.join(mutracerLib, 'renderer', 'bvh.worker.js')],
  bundle: true,
  format: 'esm',
  outfile: path.join(root, 'web', 'bvh.worker.js'),
  minify: true,
  logLevel: 'info',
});

await build({
  entryPoints: [path.join(root, 'js', 'mutracer_sidecar.js')],
  bundle: true,
  format: 'esm',
  splitting: true,
  outdir: path.join(root, 'web'),
  entryNames: '[name].bundle',
  chunkNames: 'sidecar-chunk-[name]-[hash]',
  minify: true,
  logLevel: 'info',
});