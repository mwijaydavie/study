import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    allowedHosts: ['.e2b.app'],
    fs: { deny: ['.env', '.env.*', '*.{crt,pem}', '**/.git/**', '**/study-materials/**'] },
  },
  preview: { allowedHosts: ['.e2b.app'] },
});
