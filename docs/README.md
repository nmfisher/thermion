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

Keep redirects for retired routes in [`public/_redirects`](public/_redirects).
When moving a section, keep its old heading ID at the new destination so
existing links can still jump to it.

The [Deploy site workflow](../.github/workflows/deploy.yml) builds the docs and
publishes the WebAssembly examples under `/gallery/` on thermion.dev. It
runs for release tags and can be dispatched manually.
