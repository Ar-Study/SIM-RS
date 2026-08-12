// Matikan prerender global agar dynamic routes tidak di-crawl saat build
export const prerender = false;

// Pastikan SSR nonaktif agar berjalan murni SPA di GitHub Pages
export const ssr = false;

// Aktifkan CSR (Client-Side Rendering)
export const csr = true;