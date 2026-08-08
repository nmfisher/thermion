# Thermion documentation

The documentation site is built with Astro Starlight and deployed as a static
site to the `thermion-docs` Cloudflare Pages project.

```bash
cd docs
pnpm install
pnpm dev
```

Run `pnpm build` to type-check the Astro components and generate the production
site in `docs/dist`. Pushing documentation changes to `develop` runs
`.github/workflows/deploy-docs.yml`.

The live WebAssembly examples are hosted separately at
`thermion-examples.pages.dev`. The `ThermionExample` component loads an example
only after the reader clicks it, and keeps at most one renderer active per page.
