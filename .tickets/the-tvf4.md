---
id: the-tvf4
status: in_progress
deps: []
links: []
created: 2026-08-14T14:54:21Z
type: feature
priority: 2
assignee: Nick Fisher
tags: [dart, examples, physics]
---
# Create a Dart sample demonstrating basic physics

Create a Dart sample (thermion example) showing basic physics. Use reactphysics3d_dart for the physics simulation and thermion_dart for rendering.

## Context

- Reference app: ~/Documents/mixworld (Flutter app, mounted read-only).
  It already wires thermion_dart + reactphysics3d_dart together. Read it to
  learn the integration pattern.
- Physics package: reactphysics3d_dart (mounted read-only at
  /Volumes/T7/projects/reactphysics3d_dart). It is a git repo on branch
  master. It has an example/ dir with a heightfield example.
- The sample lives in this repo (thermion), under examples/dart.
  Follow the existing example structure (examples_lib / web_gallery).
- Physics + rendering should run in the browser (WASM), like the other
  dart examples.

## Acceptance criteria

1. New dart example under examples/dart that shows basic physics:
   objects falling, bouncing, or colliding, rendered with thermion.
2. Registered in the example registry so it appears in the web gallery
   (see examples/dart/examples_lib/lib/src/registry.dart and
   examples/dart/web_gallery).
3. Works in the browser (WASM build), verified by building/running it.
4. Code follows existing example style and passes `flutter analyze` /
   `dart analyze` where applicable.

