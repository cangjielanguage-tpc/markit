import { defineConfig } from 'tsdown'

export default defineConfig([
  {
    name: 'all-bundle-dev',
    entry: ['src/index.ts'],
    outDir: 'dist',
    format: 'iife',
    globalName: 'MarkitRenderer',
    minify: false,
    sourcemap: true,
    clean: true,
    dts: false,
    platform: 'browser',
    target: 'es2022',
    outExtensions: () => ({ js: '.markit.bundle.js' }),
    noExternal: [
      'flexsearch'
    ],
    define: {
      'process.env.NODE_ENV': '"development"',
      'import.meta': '{}'
    },
    // Use named exports
    outputOptions: {
      exports: 'named'
    }
  }
])
