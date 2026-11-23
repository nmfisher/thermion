# Thermion documentation

The documentation site is built with Astro Starlight and deployed as a static
site to the `thermion-docs` Cloudflare Pages project.

```bash
cd docs
pnpm install --frozen-lockfile
pnpm dev
```

Run `pnpm build` to type-check the Astro components and generate the production
site in `docs/dist`.

The [Deploy site workflow](../.github/workflows/deploy.yml) builds the docs and
publishes the WebAssembly examples under `/gallery/` on thermion.dev. It
runs for release tags and can be dispatched manually.
