<script setup lang="ts">
import { computed } from 'vue'

interface ArchitectureLayer {
  title: string
  subtitle: string
  color: string
  icon: string
  features: string[]
  modules?: Array<{
    name: string
    description: string
  }>
}

const coreLayer: ArchitectureLayer = {
  title: 'Core Governance Layer',
  subtitle: 'Production-hardened, court-safe substrate',
  color: 'blue',
  icon: '🔒',
  features: [
    'AnigmaCore ECS foundation',
    'DatabaseCore secure access',
    'HarmoniaSpine governance',
    'Hardware-backed ML integration',
    'Emergency security procedures'
  ]
}

const capabilityLayer: ArchitectureLayer = {
  title: 'Capability Modules',
  subtitle: 'Feature-rich ecosystem with clear contracts',
  color: 'green',
  icon: '🧩',
  features: [
    'Domain-specific functionality',
    'Reuse existing Core abstractions',
    'Clear architectural patterns',
    'Independent development',
    'Rich functionality without security compromise'
  ],
  modules: [
    { name: 'HarmoniaModule', description: 'Governed inference & reasoning safety' },
    { name: 'DiaplasionModule', description: 'Alt-media transformation (OCR, EPUB, Braille)' },
    { name: 'AccessumModule', description: 'Client workflows & automation' },
    { name: 'OutlineumModule', description: 'Creative production & publishing' },
    { name: 'PragmaModule', description: 'Work management & collaboration' },
    { name: 'ConexusModule', description: 'CRM & relationship management' },
    { name: 'CodexModule', description: 'Knowledge management & documentation' },
    { name: 'TranscriptumModule', description: 'Academic records & SIS' },
    { name: 'ObservatoriumModule', description: 'Telemetry & observability' },
    { name: 'PolytroposModule', description: 'Live-event video processing' }
  ]
}

const benefits = [
  {
    icon: '🛡️',
    title: 'Unified Foundation',
    description: 'One ECS/job core prevents fragmentation and duplicate infrastructure'
  },
  {
    icon: '⚖️',
    title: 'Governed Inference',
    description: 'Single entrypoint ensures all ML operations are auditable and court-safe'
  },
  {
    icon: '🚀',
    title: 'Rapid Evolution',
    description: 'Capability modules can evolve rapidly without compromising Core security'
  },
  {
    icon: '📋',
    title: 'Clear Contracts',
    description: 'Well-defined interfaces enable independent development and testing'
  }
]
</script>

<template>
  <section class="architecture-overview">
    <div class="layers-container">
      <!-- Core Governance Layer -->
      <div class="layer core-layer">
        <div class="layer-header">
          <span class="layer-icon">{{ coreLayer.icon }}</span>
          <div>
            <h2>{{ coreLayer.title }}</h2>
            <p class="layer-subtitle">{{ coreLayer.subtitle }}</p>
          </div>
        </div>
        <div class="layer-content">
          <ul class="feature-list">
            <li v-for="feature in coreLayer.features" :key="feature">
              <span class="feature-bullet">✓</span>
              {{ feature }}
            </li>
          </ul>
        </div>
      </div>

      <!-- Arrow -->
      <div class="layer-arrow">
        <div class="arrow-line"></div>
        <div class="arrow-head"></div>
      </div>

      <!-- Capability Modules Layer -->
      <div class="layer capability-layer">
        <div class="layer-header">
          <span class="layer-icon">{{ capabilityLayer.icon }}</span>
          <div>
            <h2>{{ capabilityLayer.title }}</h2>
            <p class="layer-subtitle">{{ capabilityLayer.subtitle }}</p>
          </div>
        </div>
        <div class="layer-content">
          <div class="features-section">
            <h3>Key Characteristics</h3>
            <ul class="feature-list">
              <li v-for="feature in capabilityLayer.features" :key="feature">
                <span class="feature-bullet">✓</span>
                {{ feature }}
              </li>
            </ul>
          </div>
          
          <div class="modules-section">
            <h3>Available Modules</h3>
            <div class="modules-grid">
              <div 
                v-for="module in capabilityLayer.modules" 
                :key="module.name"
                class="module-card"
              >
                <h4>{{ module.name }}</h4>
                <p>{{ module.description }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Benefits Section -->
    <div class="benefits-section">
      <h2>Architecture Benefits</h2>
      <div class="benefits-grid">
        <div 
          v-for="benefit in benefits" 
          :key="benefit.title"
          class="benefit-card"
        >
          <span class="benefit-icon">{{ benefit.icon }}</span>
          <h3>{{ benefit.title }}</h3>
          <p>{{ benefit.description }}</p>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.architecture-overview {
  margin: 2rem 0;
}

.layers-container {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  margin-bottom: 3rem;
}

.layer {
  border: 2px solid var(--vp-c-divider);
  border-radius: 0.75rem;
  padding: 1.5rem;
  background: var(--vp-c-bg);
}

.core-layer {
  border-color: var(--vp-c-brand);
  background: linear-gradient(135deg, var(--vp-c-bg) 0%, rgba(var(--vp-c-brand-rgb), 0.05) 100%);
}

.capability-layer {
  border-color: var(--vp-c-green);
  background: linear-gradient(135deg, var(--vp-c-bg) 0%, rgba(var(--vp-c-green-rgb), 0.05) 100%);
}

.layer-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.layer-icon {
  font-size: 2.5rem;
  line-height: 1;
}

.layer-header h2 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
}

.layer-subtitle {
  margin: 0.25rem 0 0 0;
  color: var(--vp-c-text-2);
  font-size: 1rem;
}

.layer-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.feature-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.feature-list li {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  font-size: 0.95rem;
}

.feature-bullet {
  color: var(--vp-c-brand);
  font-weight: bold;
  flex-shrink: 0;
  margin-top: 0.1rem;
}

.layer-arrow {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 3rem;
}

.arrow-line {
  width: 2px;
  height: 2rem;
  background: var(--vp-c-divider);
}

.arrow-head {
  width: 0;
  height: 0;
  border-left: 0.5rem solid transparent;
  border-right: 0.5rem solid transparent;
  border-top: 0.75rem solid var(--vp-c-divider);
}

.features-section,
.modules-section {
  background: var(--vp-c-bg-alt);
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.5rem;
  padding: 1.25rem;
}

.features-section h3,
.modules-section h3 {
  margin: 0 0 1rem 0;
  font-size: 1.1rem;
  font-weight: 600;
}

.modules-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.module-card {
  background: var(--vp-c-bg);
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.5rem;
  padding: 1rem;
}

.module-card h4 {
  margin: 0 0 0.5rem 0;
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--vp-c-brand);
}

.module-card p {
  margin: 0;
  font-size: 0.85rem;
  color: var(--vp-c-text-2);
  line-height: 1.4;
}

.benefits-section {
  margin-top: 3rem;
  padding-top: 2rem;
  border-top: 2px solid var(--vp-c-divider);
}

.benefits-section h2 {
  text-align: center;
  margin: 0 0 2rem 0;
  font-size: 1.75rem;
  font-weight: 600;
}

.benefits-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
}

.benefit-card {
  text-align: center;
  padding: 1.5rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.75rem;
  background: var(--vp-c-bg);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.benefit-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.benefit-icon {
  display: block;
  font-size: 2.5rem;
  margin-bottom: 1rem;
}

.benefit-card h3 {
  margin: 0 0 0.75rem 0;
  font-size: 1.1rem;
  font-weight: 600;
}

.benefit-card p {
  margin: 0;
  font-size: 0.9rem;
  color: var(--vp-c-text-2);
  line-height: 1.5;
}

@media (max-width: 768px) {
  .layers-container {
    gap: 1.5rem;
  }
  
  .layer {
    padding: 1.25rem;
  }
  
  .layer-header {
    gap: 0.75rem;
  }
  
  .layer-icon {
    font-size: 2rem;
  }
  
  .modules-grid {
    grid-template-columns: 1fr;
  }
  
  .benefits-grid {
    grid-template-columns: 1fr;
  }
}
</style>