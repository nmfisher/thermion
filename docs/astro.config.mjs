import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://thermion.dev',
  integrations: [
    starlight({
      title: 'Thermion',
      description: 'Cross-platform 3D rendering for Dart and Flutter',
      favicon: '/logo_square.png',
      customCss: ['./src/styles/custom.css'],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/nmfisher/thermion',
        },
      ],
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Overview', slug: 'index' },
            { label: 'Getting Started', slug: 'getting_started' },
            { label: 'Quick Start', slug: 'quickstart' },
            { label: 'Viewer', slug: 'viewer' },
          ],
        },
        {
          label: 'Platforms',
          items: [
            { label: 'Android', slug: 'android' },
            { label: 'iOS', slug: 'ios' },
            { label: 'Web', slug: 'web' },
            { label: 'Linux', slug: 'linux' },
          ],
        },
        {
          label: 'More',
          items: [
            { label: 'Filament', slug: 'filament' },
            { label: 'Debugging', slug: 'debugging' },
            { label: 'Showcase', slug: 'showcase' },
            { label: 'Contributing', slug: 'contributing' },
            { label: 'Playground', link: 'https://dartpad.thermion.dev' },
            { label: 'Discord', link: 'https://discord.gg/h2VdDK3EAQ' },
          ],
        },
      ],
    }),
  ],
});
