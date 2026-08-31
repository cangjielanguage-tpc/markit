#!/usr/bin/env node

import { promises as fs } from 'fs'
import { join, dirname, normalize, resolve } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const projectRoot = join(__dirname, '..')
const distDir = join(projectRoot, 'dist')
const nodeModulesDir = join(projectRoot, 'node_modules')
const assetsDir = join(projectRoot, '..', 'assets')

interface AssetConfig {
  source: string
  dest: string
  pattern?: RegExp
}

const assets: AssetConfig[] = [
  // Bundle files to assets/js
  {
    source: join(distDir, 'index.iife.markit.bundle.js'),
    dest: join(assetsDir, 'js', 'markit.bundle.js')
  }
]

async function ensureDir(dir: string): Promise<void> {
  try {
    await fs.access(dir)
  } catch {
    await fs.mkdir(dir, { recursive: true })
  }
}

async function copyFile(source: string, dest: string): Promise<void> {
  try {
    await fs.access(source)
    await ensureDir(dirname(dest))
    await fs.copyFile(source, dest)
    console.log(`Copied: ${source} -> ${dest}`)
  } catch (error) {
    console.warn(`Warning: Could not copy ${source}:`, error)
  }
}

async function copyDirectory(source: string, dest: string, pattern?: RegExp): Promise<void> {
  try {
    const stats = await fs.stat(source)
    if (!stats.isDirectory()) {
      if (!pattern || pattern.test(source)) {
        await copyFile(source, dest)
      }
      return
    }

    await ensureDir(dest)
    const entries = await fs.readdir(source, { withFileTypes: true })

    for (const entry of entries) {
      const sourcePath = join(source, entry.name)
      const destPath = join(dest, entry.name)

      if (entry.isDirectory()) {
        await copyDirectory(sourcePath, destPath, pattern)
      } else if (!pattern || pattern.test(entry.name)) {
        await copyFile(sourcePath, destPath)
      }
    }
  } catch (error) {
    console.warn(`Warning: Could not copy ${source}:`, error)
  }
}

async function copyAssets(): Promise<void> {
  console.log('Copying assets to markit-kit/assets...')
  
  // Ensure target directories exist
  await ensureDir(join(assetsDir, 'css'))
  await ensureDir(join(assetsDir, 'js'))

  for (const asset of assets) {
    try {
      const stats = await fs.stat(asset.source)
      if (stats.isDirectory()) {
        await copyDirectory(asset.source, asset.dest, asset.pattern)
      } else {
        await copyFile(asset.source, asset.dest)
      }
    } catch (error) {
      console.warn(`Warning: Could not copy asset ${asset.source}:`, error)
    }
  }

  console.log('Assets copied successfully to markit-kit/assets!')
}

// Run if called directly
if (normalize(fileURLToPath(import.meta.url)) === normalize(resolve(process.argv[1]))) {
  copyAssets().catch(console.error)
}

export { copyAssets }
