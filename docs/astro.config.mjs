import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://thermion.dev',
  integrations: [
    starlight({
      title: 'Thermion',
      description: 'Cross-platform 3D rendering for Dart and Flutter',
      head: [{ tag: 'link', attrs: { rel: 'sitemap', href: '/sitemap.xml' } }],
      favicon: '/logo_square.png',
      // The brand wordmark (logo.png already includes the "Thermion" name), so
      // it replaces the text title in the sidebar header. Dropped during the
      // Astro migration (#216) — reinstated.
      logo: { src: './src/assets/logo.png', replacesTitle: true },
      customCss: ['./src/styles/custom.css'],
      components: {
        // Overrides Starlight's site title to append the released Thermion
        // version (read from thermion_dart/pubspec.yaml at build time) next to
        // the logo. See src/components/SiteTitle.astro.
        SiteTitle: './src/components/SiteTitle.astro',
        // Starlight renders Pagination inside the footer on every page.
        Pagination: './src/components/FooterAttribution.astro',
      },
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/nmfisher/thermion',
        },
      ],
      sidebar: [
        { label: 'Overview', slug: 'index' },
        { slug: 'quickstart' },
        { slug: 'viewer' },
        { slug: 'materials' },
        { slug: 'platforms' },
        { slug: 'web' },
        { slug: 'build_configuration' },
      ],
    }),
  ],
});
