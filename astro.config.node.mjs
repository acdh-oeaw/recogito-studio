import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import node from '@astrojs/node';
import pluginNER from '@recogito/plugin-ner';
import pluginTEIInliner from '@recogito/plugin-tei-inliner';
import pluginRevisions from '@recogito/plugin-revisions';
import pluginGeotagger from '@recogito/plugin-geotagging';

const siteUrl = process.env.SITE_URL || 'http://localhost:4321';
const url = new URL(siteUrl);
const allowedDomain = url.hostname;
// https://astro.build/config
export default defineConfig({
  integrations: [
    react(),
    pluginNER(),
    pluginTEIInliner(),
    pluginRevisions(),
    pluginGeotagger(),
  ],
  output: 'server',
  i18n: {
    locales: ['en', 'de'],
    defaultLocale: 'en',
    routing: {
      prefixDefaultLocale: true,
    },
  },
  adapter: node({
    mode: 'standalone',
  }),
  vite: {
    ssr: {
      noExternal: ['clsx', '@phosphor-icons/*', '@radix-ui/*']
    }
  },
  security: {
    checkOrigin: true,
    allowedDomains: [allowedDomain]
  }
});
