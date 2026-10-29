import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  resolve: {
    // The report parser, comparison rules, question generator and safety layer are shared with the Edge Functions.
    alias: { '@core': decodeURIComponent(new URL('./supabase/functions/_shared/core', import.meta.url).pathname) },
  },
  server: { port: 5173 },
});
