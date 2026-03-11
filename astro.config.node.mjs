// Import Astro configuration helpers and integrations
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import node from '@astrojs/node';

// Import Recogito Studio plugins
import pluginNER from '@recogito/plugin-ner';
import pluginTEIInliner from '@recogito/plugin-tei-inliner';
import pluginRevisions from '@recogito/plugin-revisions';
import pluginGeotagger from '@recogito/plugin-geotagging';

// Read SITE_URL from environment variables.
// Fallback is used in local development.
const siteUrl = process.env.SITE_URL || 'http://localhost:4321';
const url = new URL(siteUrl);

// Extract the hostname only, same as original variable.
// Example: "site.com"
const allowedDomain = url.hostname;

// Extract scheme (protocol without ":")
// Example: "https"
const scheme = url.protocol.replace(':', '');

// Export Astro configuration
export default defineConfig({
  // Used for generating correct canonical URLs, sitemap, etc.
  site: siteUrl,

  integrations: [
    react(),
    pluginNER(),
    pluginTEIInliner(),
    pluginRevisions(),
    pluginGeotagger(),
  ],

  // Ensures Astro builds a server output (dist/server/entry.mjs)
  output: 'server',

  // Internationalization
  i18n: {
    locales: ['en', 'de'],
    defaultLocale: 'en',
    routing: {
      prefixDefaultLocale: true,
    },
  },

  // Node adapter — standalone bundles dependencies into final output
  adapter: node({
    mode: 'standalone',
  }),

  vite: {
    ssr: {
      // Recogito frontend libs must not be externalized in SSR mode
      noExternal: ['clsx', '@phosphor-icons/*', '@radix-ui/*'],
    },
  },

  // Astro Security configuration
  security: {
    checkOrigin: true,

    // IMPORTANT:
    // Astro requires an array of objects, not strings.
    // Here we directly use `allowedDomain` inside the required object.
    allowedDomains: [
      {
        scheme,           // e.g., "https"
        host: allowedDomain, // e.g., "site.com"
      },
    ],
  },
});
