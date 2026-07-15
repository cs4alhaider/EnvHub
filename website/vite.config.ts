import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// GitHub Pages serves the site at https://cs4alhaider.github.io/EnvHub/ —
// the base only applies to production builds so local dev stays at "/".
export default defineConfig(({ command }) => ({
  plugins: [react()],
  base: command === 'build' ? '/EnvHub/' : '/',
}))
