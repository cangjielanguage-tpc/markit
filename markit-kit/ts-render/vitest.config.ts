import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    setupFiles: ['./src/test-setup.ts']
  },
  esbuild: {
    target: 'es2022'
  },
  resolve: {
    conditions: ['node', 'import']
  }
})