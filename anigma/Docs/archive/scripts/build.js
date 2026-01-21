#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🚀 Starting Anigma Documentation Build...\n');

// Step 1: Generate basic diagrams
console.log('📊 Step 1: Generating basic diagrams...');
try {
  execSync('node generate-fixed-diagrams.js', { stdio: 'inherit', cwd: __dirname });
  console.log('✅ Basic diagrams generated successfully\n');
} catch (error) {
  console.error('❌ Basic diagram generation failed:', error.message);
  process.exit(1);
}

// Step 1.5: Generate enhanced module diagrams
console.log('🏗️ Step 1.5: Generating enhanced module diagrams...');
try {
  execSync('node generate-enhanced-modules.js', { stdio: 'inherit', cwd: __dirname });
  console.log('✅ Enhanced module diagrams generated successfully\n');
} catch (error) {
  console.error('❌ Enhanced module diagram generation failed:', error.message);
  process.exit(1);
}

// Step 1.7: Generate dynamic module documentation
console.log('📚 Step 1.7: Generating dynamic module documentation...');
try {
  execSync('node generate-module-docs.js', { stdio: 'inherit', cwd: __dirname });
  console.log('✅ Dynamic module documentation generated successfully\n');
} catch (error) {
  console.error('❌ Dynamic module documentation generation failed:', error.message);
  process.exit(1);
}

// Step 2: Build VitePress site
console.log('📚 Step 2: Building VitePress site...');
try {
  execSync('npx vitepress build', { stdio: 'inherit', cwd: path.dirname(__dirname) });
  console.log('✅ VitePress build completed successfully\n');
} catch (error) {
  console.error('❌ VitePress build failed:', error.message);
  process.exit(1);
}

// Step 3: Validate generated files
console.log('🔍 Step 3: Validating generated files...');
const distPath = path.join(__dirname, '..', '.vitepress', 'dist');
const diagramsPath = path.join(__dirname, '..', 'diagrams', 'generated');

if (fs.existsSync(distPath)) {
  console.log('✅ VitePress dist directory exists');
} else {
  console.error('❌ VitePress dist directory not found');
  process.exit(1);
}

if (fs.existsSync(diagramsPath)) {
  const manifestPath = path.join(diagramsPath, 'manifest.json');
  if (fs.existsSync(manifestPath)) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    console.log(`✅ Generated ${manifest.diagrams.length} diagrams`);
  }
} else {
  console.error('❌ Generated diagrams directory not found');
  process.exit(1);
}

console.log('\n🎉 Documentation build completed successfully!');
console.log('📁 Output available in: .vitepress/dist');
console.log('📊 Diagrams available in: diagrams/generated');