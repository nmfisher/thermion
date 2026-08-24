import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://thermion.dev',
  integrations: [
    starlight({
      title: 'Thermion',
      description: 'Cross-platform 3D rendering for Dart and Flutter',
      favicon: '/logo_square.png',
      // The brand wordmark (logo.png already includes the "Thermion" name), so
      // it replaces the text title in the sidebar header. Dropped during the
      // Astro migration (#216) — reinstated.
      logo: { src: './src/assets/logo.png', replacesTitle: true },
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
            { label: 'Entities', slug: 'entities' },
            { label: 'Lighting', slug: 'lighting' },
            { label: 'Shadows', slug: 'shadows' },
            { label: 'Camera Manipulation', slug: 'camera_manipulation' },
            { label: 'Animations', slug: 'animations' },
            { label: 'Materials & Textures', slug: 'materials' },
          ],
        },
        {
          label: 'Platforms',
          items: [
            { label: 'Android', slug: 'android' },
            { label: 'iOS', slug: 'ios' },
            { label: 'Web', slug: 'web' },
            { label: 'Windows', slug: 'windows' },
            { label: 'Linux', slug: 'linux' },
          ],
        },
        {
          label: 'More',
          items: [
            { label: 'Filament', slug: 'filament' },
            { label: 'Filament API', slug: 'filament_api' },
            { label: 'Build Configuration', slug: 'build_configuration' },
            { label: 'Debugging', slug: 'debugging' },
            { label: 'Contributing', slug: 'contributing' },
            { label: 'Discord', link: 'https://discord.gg/h2VdDK3EAQ' },
          ],
        },
      ],
    }),
  ],
});
