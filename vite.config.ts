import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import postcss from 'rollup-plugin-postcss';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    postcss(),
  ],
  server: {
    open: true,
  },
  css: {
    postcss: {
      plugins: [
        require('tailwindcss')(),
        require('autoprefixer')(),
      ],
    },
  },
});