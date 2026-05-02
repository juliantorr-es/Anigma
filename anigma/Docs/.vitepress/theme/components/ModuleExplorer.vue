<template>
  <div class="module-explorer">
    <div class="explorer-header">
      <h2>🏗️ Anigma Module Explorer</h2>
      <div class="controls">
        <select v-model="selectedLayer" @change="filterModules">
          <option value="all">All Layers</option>
          <option value="core">Core Governance</option>
          <option value="capability">Capability Modules</option>
        </select>
        <select v-model="selectedCategory" @change="filterModules">
          <option value="all">All Categories</option>
          <option v-for="category in categories" :key="category" :value="category">
            {{ formatCategory(category) }}
          </option>
        </select>
      </div>
    </div>

    <div class="explorer-content">
      <div class="module-list">
        <div 
          v-for="module in filteredModules" 
          :key="module.name"
          :class="['module-card', module.layer, { active: selectedModule === module.name }]"
          @click="selectModule(module.name)"
        >
          <div class="module-header">
            <h3>{{ module.name }}</h3>
            <span class="layer-badge" :class="module.layer">
              {{ module.layer === 'core' ? 'Core' : 'Capability' }}
            </span>
          </div>
          <p class="module-purpose">{{ module.purpose }}</p>
          <div class="module-stats">
            <span class="stat">{{ module.components.length }} components</span>
            <span class="stat">{{ module.dependencies.length }} dependencies</span>
          </div>
        </div>
      </div>

      <div class="module-detail" v-if="selectedModuleData">
        <h3>{{ selectedModuleData.name }}</h3>
        <p class="purpose">{{ selectedModuleData.purpose }}</p>
        
        <div class="detail-section">
          <h4>🧩 Components</h4>
          <div class="component-list">
            <div v-for="component in selectedModuleData.components" :key="component" class="component-item">
              {{ component }}
            </div>
          </div>
        </div>

        <div class="detail-section">
          <h4>🔗 Dependencies</h4>
          <div class="dependency-list">
            <div v-for="dep in selectedModuleData.dependencies" :key="dep" class="dependency-item">
              <span class="dep-name">{{ dep }}</span>
              <span class="dep-type" :class="getDependencyType(dep)">
                {{ getDependencyType(dep) }}
              </span>
            </div>
          </div>
        </div>

        <div class="detail-section" v-if="selectedModuleData.category">
          <h4>📂 Category</h4>
          <span class="category-badge" :class="selectedModuleData.category">
            {{ formatCategory(selectedModuleData.category) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const selectedLayer = ref('all')
const selectedCategory = ref('all')
const selectedModule = ref('')
const moduleData = ref({})

const categories = computed(() => {
  const cats = new Set()
  Object.values(moduleData.value.capability?.modules || {}).forEach(module => {
    if (module.category) cats.add(module.category)
  })
  return Array.from(cats)
})

const filteredModules = computed(() => {
  const modules = []
  
  // Add core modules
  if (selectedLayer.value === 'all' || selectedLayer.value === 'core') {
    Object.entries(moduleData.value.core?.modules || {}).forEach(([name, info]) => {
      modules.push({
        name,
        ...info,
        layer: 'core'
      })
    })
  }
  
  // Add capability modules
  if (selectedLayer.value === 'all' || selectedLayer.value === 'capability') {
    Object.entries(moduleData.value.capability?.modules || {}).forEach(([name, info]) => {
      if (selectedCategory.value === 'all' || info.category === selectedCategory.value) {
        modules.push({
          name,
          ...info,
          layer: 'capability'
        })
      }
    })
  }
  
  return modules
})

const selectedModuleData = computed(() => {
  if (!selectedModule.value) return null
  
  const coreModule = moduleData.value.core?.modules[selectedModule.value]
  if (coreModule) {
    return { name: selectedModule.value, ...coreModule, layer: 'core' }
  }
  
  const capModule = moduleData.value.capability?.modules[selectedModule.value]
  if (capModule) {
    return { name: selectedModule.value, ...capModule, layer: 'capability' }
  }
  
  return null
})

const selectModule = (moduleName) => {
  selectedModule.value = moduleName
}

const filterModules = () => {
  selectedModule.value = ''
}

const formatCategory = (category) => {
  return category.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
}

const getDependencyType = (dep) => {
  if (dep.startsWith('Anigma') || dep === 'DatabaseCore' || dep === 'ContractsCore') {
    return 'core'
  }
  return 'external'
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
.module-explorer {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.explorer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  flex-wrap: wrap;
  gap: 20px;
}

.controls {
  display: flex;
  gap: 15px;
}

.controls select {
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: white;
  font-size: 14px;
}

.explorer-content {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 30px;
}

.module-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
  max-height: 70vh;
  overflow-y: auto;
}

.module-card {
  border: 2px solid #e1e5e9;
  border-radius: 8px;
  padding: 20px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.module-card:hover {
  border-color: #0969da;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.module-card.active {
  border-color: #0969da;
  background-color: #f6f8fa;
}

.module-card.core {
  border-left: 4px solid #0969da;
}

.module-card.capability {
  border-left: 4px solid #8250df;
}

.module-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.module-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.layer-badge {
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
  color: white;
}

.layer-badge.core {
  background-color: #0969da;
}

.layer-badge.capability {
  background-color: #8250df;
}

.module-purpose {
  margin: 0 0 15px 0;
  color: #656d76;
  font-size: 14px;
  line-height: 1.4;
}

.module-stats {
  display: flex;
  gap: 15px;
}

.stat {
  font-size: 12px;
  color: #656d76;
}

.module-detail {
  background: #f6f8fa;
  border-radius: 8px;
  padding: 25px;
  max-height: 70vh;
  overflow-y: auto;
}

.module-detail h3 {
  margin: 0 0 10px 0;
  font-size: 20px;
  font-weight: 600;
}

.purpose {
  color: #656d76;
  margin-bottom: 25px;
  font-style: italic;
}

.detail-section {
  margin-bottom: 25px;
}

.detail-section h4 {
  margin: 0 0 15px 0;
  font-size: 16px;
  font-weight: 600;
}

.component-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.component-item {
  background: white;
  border: 1px solid #d1d9e0;
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  font-family: 'SF Mono', Monaco, monospace;
}

.dependency-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dependency-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: white;
  border: 1px solid #d1d9e0;
  border-radius: 6px;
  padding: 8px 12px;
}

.dep-name {
  font-family: 'SF Mono', Monaco, monospace;
  font-size: 13px;
}

.dep-type {
  padding: 2px 6px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 500;
  color: white;
}

.dep-type.core {
  background-color: #0969da;
}

.dep-type.external {
  background-color: #f85149;
}

.category-badge {
  padding: 6px 12px;
  border-radius: 15px;
  font-size: 13px;
  font-weight: 500;
  color: white;
}

.category-badge.ai-governance { background-color: #f85149; }
.category-badge.media-processing { background-color: #0969da; }
.category-badge.knowledge-management { background-color: #8250df; }
.category-badge.education { background-color: #7c3aed; }
.category-badge.project-management { background-color: #059669; }
.category-badge.crm { background-color: #0891b2; }
.category-badge.monitoring { background-color: #dc2626; }

@media (max-width: 768px) {
  .explorer-content {
    grid-template-columns: 1fr;
  }
  
  .explorer-header {
    flex-direction: column;
    align-items: stretch;
  }
  
  .controls {
    justify-content: center;
  }
}
</style>