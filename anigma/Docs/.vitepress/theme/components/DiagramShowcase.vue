<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface DiagramData {
  name: string
  description: string
  svgPath: string
  category: string
}

const diagramData = ref<DiagramData[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    const response = await fetch('/diagrams/generated/manifest.json')
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const manifest = await response.json()
    diagramData.value = manifest.diagrams.map((d: any) => ({
      name: d.name,
      description: `${d.category} - ${d.name}`,
      svgPath: d.svg,
      category: d.category
    }))
    
    console.log('Loaded diagrams:', diagramData.value)
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load diagrams'
    console.error('Diagram loading error:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="diagram-showcase">
    <div v-if="loading" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Loading diagrams...</p>
    </div>
    
    <div v-else-if="error" class="error-state">
      <p>❌ {{ error }}</p>
    </div>
    
    <div v-else class="diagram-content">
      <!-- Architecture Overview -->
      <section class="diagram-section">
        <h2>🏗️ Architecture Overview</h2>
        <div class="diagram-grid">
          <div 
            v-for="diagram in diagramData.filter(d => d.category === 'architecture')" 
            :key="diagram.name"
            class="diagram-item"
          >
            <div class="diagram-image">
              <img 
                :src="diagram.svgPath" 
                :alt="diagram.name"
                loading="lazy"
              />
            </div>
            <div class="diagram-info">
              <h3>{{ diagram.name }}</h3>
              <p>{{ diagram.description }}</p>
            </div>
          </div>
        </div>
      </section>
      
      <!-- Workflow Diagrams -->
      <section class="diagram-section">
        <h2>🔄 Workflow Diagrams</h2>
        <div class="diagram-grid">
          <div 
            v-for="diagram in diagramData.filter(d => d.category === 'workflows')" 
            :key="diagram.name"
            class="diagram-item"
          >
            <div class="diagram-image">
              <img 
                :src="diagram.svgPath" 
                :alt="diagram.name"
                loading="lazy"
              />
            </div>
            <div class="diagram-info">
              <h3>{{ diagram.name }}</h3>
              <p>{{ diagram.description }}</p>
            </div>
          </div>
        </div>
      </section>
      
      <!-- Data Flow Diagrams -->
      <section class="diagram-section">
        <h2>📊 Data Flow Diagrams</h2>
        <div class="diagram-grid">
          <div 
            v-for="diagram in diagramData.filter(d => d.category === 'data-flows')" 
            :key="diagram.name"
            class="diagram-item"
          >
            <div class="diagram-image">
              <img 
                :src="diagram.svgPath" 
                :alt="diagram.name"
                loading="lazy"
              />
            </div>
            <div class="diagram-info">
              <h3>{{ diagram.name }}</h3>
              <p>{{ diagram.description }}</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.diagram-showcase {
  margin: 2rem 0;
}

.loading-state,
.error-state {
  text-align: center;
  padding: 4rem 2rem;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--vp-c-brand);
  border-top: 3px solid transparent;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 1rem;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.diagram-content {
  max-width: 1200px;
  margin: 0 auto;
}

.diagram-section {
  margin-bottom: 4rem;
}

.diagram-section h2 {
  font-size: 1.75rem;
  font-weight: 600;
  margin-bottom: 2rem;
  color: var(--vp-c-brand);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.diagram-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 2rem;
}

.diagram-item {
  background: var(--vp-c-bg);
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.75rem;
  padding: 1.5rem;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.diagram-item:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
}

.diagram-image {
  margin-bottom: 1rem;
  border-radius: 0.5rem;
  overflow: hidden;
  background: var(--vp-c-bg-alt);
  padding: 1rem;
  text-align: center;
}

.diagram-image img {
  width: 100%;
  max-height: 250px;
  object-fit: contain;
  border-radius: 0.25rem;
}

.diagram-info h3 {
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0 0 0.75rem 0;
  color: var(--vp-c-brand);
}

.diagram-info p {
  font-size: 0.95rem;
  color: var(--vp-c-text-2);
  margin: 0;
  line-height: 1.5;
}

/* Responsive Design */
@media (max-width: 768px) {
  .diagram-grid {
    grid-template-columns: 1fr;
    gap: 1.5rem;
  }
  
  .diagram-section {
    margin-bottom: 3rem;
  }
  
  .diagram-item {
    padding: 1rem;
  }
  
  .diagram-image img {
    max-height: 200px;
  }
}

@media (max-width: 480px) {
  .diagram-showcase {
    margin: 1rem 0;
  }
  
  .diagram-section h2 {
    font-size: 1.5rem;
  }
}
</style>