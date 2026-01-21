import { defineConfig } from 'vitepress'
import { readFileSync } from 'fs'
import { execSync } from 'child_process'
import { fileURLToPath } from 'url'
import path from 'path'

const configDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.join(configDir, '..', '..')

function getDocsLastUpdated() {
  try {
    const command = 'git log -1 --format=%cI -- Docs'
    return execSync(command, { encoding: 'utf-8', cwd: repoRoot }).trim() || null
  } catch {
    return null
  }
}

function loadSigmaStatus() {
  try {
    const statusPath = path.join(configDir, '..', 'status', 'status.json')
    const raw = readFileSync(statusPath, 'utf-8')
    return JSON.parse(raw)
  } catch {
    return null
  }
}

export default defineConfig({
  title: "Anigma Documentation",
  description: "A governed, local-first Swift stack for institutional AI with two-tier architecture.",
  lastUpdated: true,
  ignoreDeadLinks: true,
  themeConfig: {
    lastUpdatedText: 'Docs last updated',
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Architecture', link: '/architecture/overview' },
      { text: 'Core Governance', link: '/architecture/core-governance' },
      { text: 'Capability Modules', link: '/architecture/capability-modules' },
      { text: 'Getting Started', link: '/guide/getting-started' },
      { text: 'Product', link: '/product/hero-story' },
      { text: 'Strategy', link: '/strategy/monetization-strategy' },
      { text: 'Atlas', link: '/atlas' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'What is Anigma?', link: '/' },
          { text: 'Two-Tier Architecture', link: '/llm-context/00-two-tier-architecture-guide' }
        ]
      },
      {
        text: 'Getting Started',
        items: [
          { text: 'Getting Started', link: '/guide/getting-started' }
        ]
      },
      {
        text: 'Architecture',
        items: [
          { text: 'Overview', link: '/architecture/overview' },
          { text: 'Core Governance Layer', link: '/architecture/core-governance' },
          { text: 'Capability Modules', link: '/architecture/capability-modules' },
          { text: 'Local Inference Strategy', link: '/architecture/local-inference-strategy' },
          { text: 'ML Worker Integration', link: '/architecture/ml-worker-integration' },
          { text: 'Governance and Provenance', link: '/architecture/governance-and-provenance' },
          { text: 'Database Housekeeping', link: '/architecture/database-housekeeping' }
        ]
      },
      {
        text: 'Core Concepts',
        items: [
          { text: 'ECS Principles', link: '/concepts/ecs' },
          { text: 'Governance Model', link: '/concepts/governance-model' }
        ]
      },
      {
        text: 'Capability Modules',
        items: [
          { text: 'Harmonia (Governed Inference)', link: '/llm-context/01-core-governance-deep-dive' },
          { text: 'Diaplasion (Alt-Media)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Accessum (Client Workflows)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Outlineum (Creative)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Pragma (Work Management)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Conexus (CRM)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Codex (Knowledge)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Transcriptum (Academic)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Observatorium (Telemetry)', link: '/llm-context/02-capability-modules-development' },
          { text: 'Polytropos (Video)', link: '/llm-context/02-capability-modules-development' }
        ]
      },
      {
        text: 'Product & Strategy',
        items: [
          { text: 'Hero Product', link: '/product/hero-story' },
          { text: 'Features', link: '/product/features' },
          { text: 'Operator UI Specification', link: '/product/operator-ui-spec' },
          { text: 'Market Positioning', link: '/strategy/market-positioning' },
          { text: 'Monetization Strategy', link: '/strategy/monetization-strategy' }
        ]
      },
      {
        text: 'Governance & Security',
        items: [
          { text: 'Accessibility Policy', link: '/governance/accessibility-policy' },
          { text: 'Agent Governance Model', link: '/governance/agent-governance-model' },
          { text: 'Security & Privacy Overview', link: '/security/overview' },
          { text: 'Data Governance', link: '/legal/DATA-GOVERNANCE.md' },
          { text: 'Product Tiers', link: '/legal/PRODUCT-TIERS.md' }
        ]
      },
      {
        text: 'Development',
        items: [
          { text: 'Agent Workflows', link: '/llm-context/03-agent-workflows-procedures' },
          { text: 'Job & Workflow Governance', link: '/llm-context/03-job-workflow-and-harmonia-cli-governance' },
          { text: 'Implementation Rules', link: '/ImplementationRules.md' },
          { text: 'Technical Debt', link: '/TechDebt.md' },
          { text: 'Contributing', link: '/community/contributing.md' }
        ]
      },
      {
        text: 'Deployment & Operations',
        items: [
          { text: 'Deployment Overview', link: '/deployment/overview' },
          { text: 'Production Hardening', link: '/ProductionGradeImplementation.md' },
          { text: 'MLX Strategy', link: '/llm-context/05-mlx-strategy-and-local-first-ai' }
        ]
      },
      {
        text: 'Reference',
        items: [
          { text: 'Architecture Diagrams', link: '/diagrams' },
          { text: 'Agent Contract', link: '/AGENTS.md' },
          { text: 'Anigma Constitution', link: '/AnigmaConstitution.md' },
          { text: 'Roadmap', link: '/Roadmap.md' },
          { text: 'Interactive Atlas', link: '/atlas' }
        ]
      }
    ],
    projectStatus: {
      ...(loadSigmaStatus() ?? {}),
      docsLastUpdated: getDocsLastUpdated(),
      statusSource: '/status/status.json'
    }
  }
})
