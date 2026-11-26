# Contribute to Thermion

If you'd like help getting started, [join us on Discord](https://discord.gg/h2VdDK3EAQ).
Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) so
release tooling can generate changelogs.

From the repository root, run `make materials` to rebuild Thermion's bundled
materials against the local Filament tools in `FILAMENT_PATH`. Run
`make bindings` to regenerate FFI bindings. See the [material build
internals](docs/material-build-internals.md) for compiler and cache behavior,
and the [web guide](https://thermion.dev/web/#building-the-wasm-locally) for
building a local WASM engine.
