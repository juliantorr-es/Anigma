#!/usr/bin/env node
const fs = require('fs')
const path = require('path')

const repoRoot = path.resolve(process.cwd())
const sourcesDir = path.join(repoRoot, 'Sources')
const summaryPath = path.join(repoRoot, 'Docs', 'automation', 'ModuleSummary.json')

if (!fs.existsSync(summaryPath)) {
  console.error('ModuleSummary.json not found. Run `npm run docs:sync` first.')
  process.exit(1)
}

const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf-8'))

// 1. Validate moduleCount
if (summary.moduleCount !== summary.modules.length) {
  console.error(`Error: Mismatch in module count. Expected ${summary.modules.length}, but found ${summary.moduleCount}.`)
  process.exit(1)
}

// 2. Re-scan Sources directory and validate modules and file counts
const currentModuleDirs = fs
  .readdirSync(sourcesDir)
  .filter((name) => {
    const candidate = path.join(sourcesDir, name)
    return fs.statSync(candidate).isDirectory()
  })
  .sort()

if (currentModuleDirs.length !== summary.moduleCount) {
  console.error(`Error: Module count has changed. Run 'npm run docs:sync'.`)
  process.exit(1)
}

for (let i = 0; i < currentModuleDirs.length; i++) {
  const moduleName = currentModuleDirs[i]
  const summaryModule = summary.modules[i]

  if (moduleName !== summaryModule.name) {
    console.error(`Error: Module name mismatch. Expected ${summaryModule.name}, but found ${moduleName}. Run 'npm run docs:sync'.`)
    process.exit(1)
  }

  const modulePath = path.join(sourcesDir, moduleName)
  const files = fs.readdirSync(modulePath)
  if (files.length !== summaryModule.files.length) {
    console.error(`Error: File count mismatch in module ${moduleName}. Run 'npm run docs:sync'.`)
    process.exit(1)
  }
}

console.log('Docs validation passed successfully.')
process.exit(0)
