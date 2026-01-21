<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface Diagram {
  name: string
  description: string
  svgPath: string
  pngPath: string
}

const props = defineProps<{
  diagrams: Diagram[]
  title?: string
  description?: string
}>()

const selectedDiagram = ref<Diagram | null>(null)
const showDetails = ref(false)

onMounted(() => {
  // Load diagram manifest
  fetch('/diagrams/generated/manifest.json')
    .then(response => response.json())
    .then(manifest => {
      console.log('Loaded diagram manifest:', manifest)
    })
    .catch(error => {
      console.error('Failed to load diagram manifest:', error)
    })
})

function selectDiagram(diagram: Diagram) {
  selectedDiagram.value = diagram
  showDetails.value = true
}

function closeDetails() {
  showDetails.value = false
  selectedDiagram.value = null
}
</script>

<template>
  <div class="diagram-gallery">
    <header v-if="title || description" class="gallery-header">
      <h2 v-if="title">{{ title }}</h2>
      <p v-if="description" class="gallery-description">{{ description }}</p>
    </header>
    
    <div class="diagram-grid">
      <div 
        v-for="diagram in diagrams" 
        :key="diagram.name"
        class="diagram-card"
        @click="selectDiagram(diagram)"
      >
        <div class="diagram-preview">
          <img 
            :src="diagram.svgPath" 
            :alt="diagram.description"
            loading="lazy"
          />
        </div>
        <div class="diagram-info">
          <h3>{{ diagram.name }}</h3>
          <p>{{ diagram.description }}</p>
        </div>
      </div>
    </div>
    
    <!-- Detail Modal -->
    <div v-if="showDetails && selectedDiagram" class="diagram-modal" @click="closeDetails">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h2>{{ selectedDiagram.name }}</h2>
          <button class="close-button" @click="closeDetails">×</button>
        </div>
        <div class="modal-body">
          <div class="diagram-display">
            <img 
              :src="selectedDiagram.svgPath" 
              :alt="selectedDiagram.description"
              class="diagram-image"
            />
          </div>
          <div class="diagram-actions">
            <a :href="selectedDiagram.svgPath" download class="action-button">
              <span class="icon">📄</span>
              Download SVG
            </a>
            <a :href="selectedDiagram.pngPath" download class="action-button">
              <span class="icon">🖼️</span>
              Download PNG
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.diagram-gallery {
  margin: 2rem 0;
}

.gallery-header {
  text-align: center;
  margin-bottom: 3rem;
}

.gallery-header h2 {
  font-size: 2rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: var(--vp-c-brand);
}

.gallery-description {
  font-size: 1.1rem;
  color: var(--vp-c-text-2);
  max-width: 600px;
  margin: 0 auto;
  line-height: 1.6;
}

.diagram-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
  gap: 2rem;
  margin-bottom: 3rem;
}

.diagram-card {
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.75rem;
  padding: 1.5rem;
  background: var(--vp-c-bg);
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.diagram-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}

.diagram-preview {
  margin-bottom: 1rem;
  border-radius: 0.5rem;
  overflow: hidden;
  background: var(--vp-c-bg-alt);
}

.diagram-preview img {
  width: 100%;
  height: 200px;
  object-fit: contain;
  transition: transform 0.2s ease;
}

.diagram-card:hover .diagram-preview img {
  transform: scale(1.05);
}

.diagram-info h3 {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
  color: var(--vp-c-brand);
}

.diagram-info p {
  font-size: 0.9rem;
  color: var(--vp-c-text-2);
  margin: 0;
  line-height: 1.4;
}

/* Modal Styles */
.diagram-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--vp-c-bg);
  border-radius: 1rem;
  max-width: 90vw;
  max-height: 90vh;
  width: 800px;
  max-height: 600px;
  overflow: hidden;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.5rem 0 1.5rem;
  border-bottom: 1px solid var(--vp-c-divider);
}

.modal-header h2 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--vp-c-text-1);
}

.close-button {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--vp-c-text-2);
  padding: 0.25rem;
  border-radius: 0.25rem;
  transition: background-color 0.2s ease;
}

.close-button:hover {
  background: var(--vp-c-bg-alt);
}

.modal-body {
  padding: 1.5rem;
  max-height: 400px;
  overflow-y: auto;
}

.diagram-display {
  text-align: center;
  margin-bottom: 1.5rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.5rem;
  padding: 1rem;
  background: var(--vp-c-bg-alt);
}

.diagram-image {
  max-width: 100%;
  max-height: 300px;
  border-radius: 0.25rem;
}

.diagram-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
}

.action-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background: var(--vp-c-brand);
  color: white;
  text-decoration: none;
  border-radius: 0.5rem;
  font-weight: 500;
  transition: background-color 0.2s ease;
}

.action-button:hover {
  background: var(--vp-c-brand-dark);
  color: white;
}

.icon {
  font-size: 1.1rem;
}

/* Responsive Design */
@media (max-width: 768px) {
  .diagram-grid {
    grid-template-columns: 1fr;
    gap: 1.5rem;
  }
  
  .modal-content {
    width: 95vw;
    max-height: 95vh;
  }
  
  .diagram-actions {
    flex-direction: column;
  }
}
</style>