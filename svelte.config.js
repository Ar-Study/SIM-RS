import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),

  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: '404.html', // Wajib untuk routing SPA agar tidak 404 saat direct access/refresh
      precompress: false,
      strict: true
    }),
    paths: {
      // base path aktif saat di GitHub Actions / production
      base: process.env.NODE_ENV === 'production' ? '/SIM-RS' : ''
    }
  }
};

export default config;