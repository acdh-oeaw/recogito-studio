import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import node from '@astrojs/node';
import pluginNER from '@recogito/plugin-ner';
import pluginTEIInliner from '@recogito/plugin-tei-inliner';
import pluginRevisions from '@recogito/plugin-revisions';
import pluginGeotagger from '@recogito/plugin-geotagging';
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
  adapter: node({
    mode: 'standalone',
  }),
  vite: {
    ssr: {
      noExternal: ['clsx', '@phosphor-icons/*', '@radix-ui/*']
    }
  }
});
