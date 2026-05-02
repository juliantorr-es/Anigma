<template>
  <div class="relationship-mapper">
    <div class="mapper-header">
      <h2>🔗 Module Relationship Mapper</h2>
      <div class="controls">
        <button @click="showDependencies = !showDependencies" :class="{ active: showDependencies }">
          Dependencies
        </button>
        <button @click="showCategories = !showCategories" :class="{ active: showCategories }">
          Categories
        </button>
        <button @click="showLayers = !showLayers" :class="{ active: showLayers }">
          Layers
        </button>
      </div>
    </div>

    <div class="mapper-content">
      <div class="diagram-container">
        <div class="diagram-view" :class="viewClass">
          <svg viewBox="0 0 1200 800" class="relationship-svg">
            <!-- Core Layer -->
            <g v-if="showLayers" class="core-layer">
              <rect x="50" y="600" width="1100" height="150" fill="#e1f5fe" stroke="#01579b" stroke-width="2" rx="8"/>
              <text x="600" y="630" text-anchor="middle" class="layer-title">Core Governance Layer</text>
              
              <!-- Core Modules -->
              <g v-for="module in coreModules" :key="module.name" class="core-module">
                <rect 
                  :x="module.x" 
                  :y="module.y" 
                  width="140" 
                  height="60" 
                  fill="#ffffff" 
                  stroke="#01579b" 
                  stroke-width="2" 
                  rx="4"
                  @click="selectModule(module)"
                  class="module-rect"
                />
                <text :x="module.x + 70" :y="module.y + 25" text-anchor="middle" class="module-name">{{ module.shortName }}</text>
                <text :x="module.x + 70" :y="module.y + 45" text-anchor="middle" class="module-purpose">{{ module.purpose }}</text>
              </g>
            </g>

            <!-- Capability Layer -->
            <g v-if="showLayers" class="capability-layer">
              <rect x="50" y="50" width="1100" height="500" fill="#f3e5f5" stroke="#4a148c" stroke-width="2" rx="8"/>
              <text x="600" y="80" text-anchor="middle" class="layer-title">Capability Modules</text>
              
              <!-- Capability Modules by Category -->
              <g v-for="(category, categoryName) in modulesByCategory" :key="categoryName" class="category-group">
                <rect 
                  :x="category.x" 
                  :y="category.y" 
                  width="200" 
                  height="180" 
                  fill="#faf5ff" 
                  stroke="#7c3aed" 
                  stroke-width="1" 
                  rx="6"
                  stroke-dasharray="5,5"
                  v-if="showCategories"
                />
                <text :x="category.x + 100" :y="category.y + 20" text-anchor="middle" class="category-title" v-if="showCategories">
                  {{ formatCategory(categoryName) }}
                </text>
                
                <g v-for="(module, index) in category.modules" :key="module.name" class="capability-module">
                  <rect 
                    :x="category.x + 20 + (index % 2) * 85" 
                    :y="category.y + 35 + Math.floor(index / 2) * 65" 
                    width="75" 
                    height="50" 
                    fill="#ffffff" 
                    :stroke="getCategoryColor(categoryName)" 
                    stroke-width="2" 
                    rx="4"
                    @click="selectModule(module)"
                    class="module-rect"
                  />
                  <text 
                    :x="category.x + 57 + (index % 2) * 85" 
                    :y="category.y + 55 + Math.floor(index / 2) * 65" 
                    text-anchor="middle" 
                    class="module-name-small"
                  >
                    {{ module.shortName }}
                  </text>
                </g>
              </g>
            </g>

            <!-- Dependencies -->
            <g v-if="showDependencies" class="dependencies">
              <defs>
                <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
                  <polygon points="0 0, 10 3.5, 0 7" fill="#666" />
                </marker>
              </defs>
              
              <!-- Draw dependency lines -->
              <line
                v-for="dep in dependencies"
                :key="`${dep.from}-${dep.to}`"
                :x1="dep.x1"
                :y1="dep.y1"
                :x2="dep.x2"
                :y2="dep.y2"
                stroke="#666"
                stroke-width="2"
                marker-end="url(#arrowhead)"
                class="dependency-line"
              />
            </g>
          </svg>
        </div>
      </div>

      <div class="module-info" v-if="selectedModuleData">
        <h3>{{ selectedModuleData.name }}</h3>
        <p class="purpose">{{ selectedModuleData.purpose }}</p>
        
        <div class="info-section">
          <h4>📊 Statistics</h4>
          <div class="stats">
            <div class="stat-item">
              <span class="stat-label">Components:</span>
              <span class="stat-value">{{ selectedModuleData.components.length }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">Dependencies:</span>
              <span class="stat-value">{{ selectedModuleData.dependencies.length }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">Layer:</span>
              <span class="stat-value">{{ selectedModuleData.layer }}</span>
            </div>
          </div>
        </div>

        <div class="info-section" v-if="selectedModuleData.dependencies.length > 0">
          <h4>🔗 Dependencies</h4>
          <div class="dependency-list">
            <div v-for="dep in selectedModuleData.dependencies" :key="dep" class="dependency-item">
              {{ dep }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const showDependencies = ref(true)
const showCategories = ref(true)
const showLayers = ref(true)
const selectedModule = ref(null)
const moduleData = ref({})

const viewClass = computed(() => {
  return {
    'show-deps': showDependencies.value,
    'show-cats': showCategories.value,
    'show-layers': showLayers.value
  }
})

const coreModules = computed(() => {
  const modules = []
  const coreData = moduleData.value.core?.modules || {}
  const positions = [
    { x: 100, y: 650 },  // AnigmaPrimitives
    { x: 300, y: 650 },  // ContractsCore  
    { x: 500, y: 650 },  // DatabaseCore
    { x: 700, y: 650 },  // AnigmaCore
  ]
  
  Object.entries(coreData).forEach(([name, info], index) => {
    if (positions[index]) {
      modules.push({
        name,
        shortName: name.replace(/Module|Core$/, ''),
        purpose: info.purpose.substring(0, 20) + '...',
        ...info,
        ...positions[index],
        layer: 'core'
      })
    }
  })
  
  return modules
})

const modulesByCategory = computed(() => {
  const categories = {}
  const capData = moduleData.value.capability?.modules || {}
  
  Object.entries(capData).forEach(([name, info]) => {
    const category = info.category || 'other'
    if (!categories[category]) {
      categories[category] = {
        modules: [],
        x: 100 + Object.keys(categories).length * 220,
        y: 120
      }
    }
    
    categories[category].modules.push({
      name,
      shortName: name.replace(/Module$/, ''),
      ...info,
      layer: 'capability'
    })
  })
  
  return categories
})

const dependencies = computed(() => {
  const deps = []
  const allModules = {}
  
  // Collect all module positions
  coreModules.value.forEach(module => {
    allModules[module.name] = module
  })
  
  Object.values(modulesByCategory.value).forEach(category => {
    category.modules.forEach((module, index) => {
      allModules[module.name] = {
        ...module,
        x: category.x + 57 + (index % 2) * 85,
        y: category.y + 55 + Math.floor(index / 2) * 65
      }
    })
  })
  
  // Generate dependency lines
  Object.entries(allModules).forEach(([name, module]) => {
    module.dependencies.forEach(dep => {
      if (allModules[dep]) {
        deps.push({
          from: name,
          to: dep,
          x1: module.x + 35,
          y1: module.y + 25,
          x2: allModules[dep].x + 35,
          y2: allModules[dep].y + 25
        })
      }
    })
  })
  
  return deps
})

const selectedModuleData = computed(() => {
  if (!selectedModule.value) return null
  return selectedModule.value
})

const selectModule = (module) => {
  selectedModule.value = module
}

const formatCategory = (category) => {
  return category.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
}

const getCategoryColor = (category) => {
  const colors = {
    'ai-governance': '#f85149',
    'media-processing': '#0969da', 
    'knowledge-management': '#8250df',
    'education': '#7c3aed',
    'project-management': '#059669',
    'crm': '#0891b2',
    'monitoring': '#dc2626'
  }
  return colors[category] || '#666'
}

onMounted(async () => {
  try {
    const response = await fetch('/diagrams/generated/enhanced-manifest.json')
    const manifest = await response.json()
    moduleData.value = manifest.moduleStructure
  } catch (error) {
    console.error('Failed to load module data:', error)
  }
})
</script>

<style scoped>
.relationship-mapper {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
}

.mapper-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  flex-wrap: wrap;
  gap: 20px;
}

.controls {
  display: flex;
  gap: 10px;
}

.controls button {
  padding: 8px 16px;
  border: 2px solid #0969da;
  background: white;
  color: #0969da;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.controls button:hover {
  background: #f6f8fa;
}

.controls button.active {
  background: #0969da;
  color: white;
}

.mapper-content {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 30px;
}

.diagram-container {
  background: white;
  border: 1px solid #e1e5e9;
  border-radius: 8px;
  overflow: hidden;
}

.diagram-view {
  width: 100%;
  height: 800px;
}

.relationship-svg {
  width: 100%;
  height: 100%;
}

.layer-title {
  font-size: 18px;
  font-weight: 600;
  fill: #24292f;
}

.category-title {
  font-size: 14px;
  font-weight: 600;
  fill: #4a148c;
}

.module-rect {
  cursor: pointer;
  transition: all 0.2s ease;
}

.module-rect:hover {
  filter: brightness(0.95);
}

.module-name {
  font-size: 12px;
  font-weight: 600;
  fill: #24292f;
}

.module-name-small {
  font-size: 10px;
  font-weight: 600;
  fill: #24292f;
}

.module-purpose {
  font-size: 10px;
  fill: #656d76;
}

.dependency-line {
  opacity: 0.6;
}

.dependency-line:hover {
  opacity: 1;
  stroke-width: 3;
}

.module-info {
  background: #f6f8fa;
  border-radius: 8px;
  padding: 25px;
  height: fit-content;
}

.module-info h3 {
  margin: 0 0 10px 0;
  font-size: 18px;
  font-weight: 600;
}

.purpose {
  color: #656d76;
  margin-bottom: 20px;
  font-style: italic;
}

.info-section {
  margin-bottom: 20px;
}

.info-section h4 {
  margin: 0 0 10px 0;
  font-size: 14px;
  font-weight: 600;
}

.stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stat-item {
  display: flex;
  justify-content: space-between;
  padding: 6px 0;
  border-bottom: 1px solid #e1e5e9;
}

.stat-label {
  font-weight: 500;
  color: #656d76;
}

.stat-value {
  font-weight: 600;
  color: #24292f;
}

.dependency-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.dependency-item {
  background: white;
  border: 1px solid #d1d9e0;
  border-radius: 4px;
  padding: 6px 10px;
  font-family: 'SF Mono', Monaco, monospace;
  font-size: 12px;
}

@media (max-width: 1024px) {
  .mapper-content {
    grid-template-columns: 1fr;
  }
  
  .diagram-view {
    height: 600px;
  }
}
</style>