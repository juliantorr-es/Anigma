<template>
  <div class="health-dashboard">
    <div class="dashboard-header">
      <h2>🏥 Architecture Health Dashboard</h2>
      <div class="last-updated">
        Last updated: {{ formatDate(lastUpdated) }}
      </div>
    </div>

    <div class="health-overview">
      <div class="score-card" :class="scoreClass">
        <div class="score-value">{{ healthScore }}</div>
        <div class="score-label">Health Score</div>
        <div class="score-max">/ 100</div>
      </div>
      
      <div class="metrics-grid">
        <div class="metric-card passed">
          <div class="metric-value">{{ summary.passed }}</div>
          <div class="metric-label">Passed</div>
        </div>
        <div class="metric-card failed">
          <div class="metric-value">{{ summary.failed }}</div>
          <div class="metric-label">Failed</div>
        </div>
        <div class="metric-card warnings">
          <div class="metric-value">{{ summary.warnings }}</div>
          <div class="metric-label">Warnings</div>
        </div>
        <div class="metric-card total">
          <div class="metric-value">{{ summary.total }}</div>
          <div class="metric-label">Total Issues</div>
        </div>
      </div>
    </div>

    <div class="validation-sections">
      <div class="section" v-for="(issues, rule) in issuesByRule" :key="rule">
        <h3>{{ getRuleName(rule) }}</h3>
        <div class="rule-description">{{ getRuleDescription(rule) }}</div>
        
        <div class="issues-list">
          <div 
            v-for="issue in issues" 
            :key="`${issue.module}-${issue.dependency || ''}`"
            class="issue-item"
            :class="issue.severity"
          >
            <div class="issue-header">
              <span class="severity-icon">
                {{ issue.severity === 'error' ? '❌' : '⚠️' }}
              </span>
              <span class="issue-module">{{ issue.module }}</span>
              <span class="issue-dependency" v-if="issue.dependency">
                → {{ issue.dependency }}
              </span>
            </div>
            <div class="issue-message">{{ issue.message }}</div>
          </div>
        </div>
      </div>
    </div>

    <div class="actions">
      <button @click="refreshData" class="btn-primary">
        🔄 Refresh Data
      </button>
      <button @click="runValidation" class="btn-secondary">
        🔍 Run Validation
      </button>
      <button @click="exportReport" class="btn-secondary">
        📄 Export Report
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const validationData = ref(null)
const lastUpdated = ref(null)

const summary = computed(() => {
  if (!validationData.value?.summary) {
    return { passed: 0, failed: 0, warnings: 0, total: 0 }
  }
  return validationData.value.summary
})

const healthScore = computed(() => {
  if (!validationData.value?.summary) return 0
  const { passed, failed, warnings } = validationData.value.summary
  const total = passed + failed
  if (total === 0) return 100
  
  const baseScore = (passed / total) * 100
  const warningPenalty = (warnings / total) * 5
  return Math.max(0, Math.round(baseScore - warningPenalty))
})

const scoreClass = computed(() => {
  const score = healthScore.value
  if (score >= 90) return 'excellent'
  if (score >= 75) return 'good'
  if (score >= 60) return 'fair'
  return 'poor'
})

const issuesByRule = computed(() => {
  if (!validationData.value?.issues) return {}
  
  const grouped = {}
  validationData.value.issues.forEach(issue => {
    if (!grouped[issue.rule]) {
      grouped[issue.rule] = []
    }
    grouped[issue.rule].push(issue)
  })
  
  return grouped
})

const getRuleName = (ruleKey) => {
  const rules = {
    'coreLayerOnly': 'Core Layer Dependencies',
    'capabilityToCore': 'Capability Dependencies',
    'noCircularDependencies': 'Circular Dependencies',
    'ecsConsistency': 'ECS Pattern Consistency',
    'namingConventions': 'Naming Conventions',
    'moduleStructure': 'Module Structure'
  }
  return rules[ruleKey] || ruleKey
}

const getRuleDescription = (ruleKey) => {
  const descriptions = {
    'coreLayerOnly': 'Core modules should only depend on other core modules',
    'capabilityToCore': 'Capability modules should only depend on Core Governance layer',
    'noCircularDependencies': 'No circular dependencies allowed between modules',
    'ecsConsistency': 'Modules should follow ECS patterns consistently',
    'namingConventions': 'Modules should follow Anigma naming conventions',
    'moduleStructure': 'Modules should have proper directory structure'
  }
  return descriptions[ruleKey] || ''
}

const formatDate = (dateString) => {
  if (!dateString) return 'Never'
  return new Date(dateString).toLocaleString()
}

const loadData = async () => {
  try {
    const response = await fetch('/data/validation-report.json')
    if (response.ok) {
      validationData.value = await response.json()
      lastUpdated.value = validationData.value.timestamp
    }
  } catch (error) {
    console.error('Failed to load validation data:', error)
  }
}

const refreshData = async () => {
  await loadData()
}

const runValidation = async () => {
  try {
    // This would trigger a server-side validation
    const response = await fetch('/api/validate', { method: 'POST' })
    if (response.ok) {
      await loadData()
    }
  } catch (error) {
    console.error('Failed to run validation:', error)
  }
}

const exportReport = () => {
  if (!validationData.value) return
  
  const reportData = {
    timestamp: new Date().toISOString(),
    healthScore: healthScore.value,
    summary: summary.value,
    issues: validationData.value.issues
  }
  
  const blob = new Blob([JSON.stringify(reportData, null, 2)], {
    type: 'application/json'
  })
  
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `architecture-health-${new Date().toISOString().split('T')[0]}.json`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.health-dashboard {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  flex-wrap: wrap;
  gap: 20px;
}

.last-updated {
  color: #656d76;
  font-size: 14px;
}

.health-overview {
  display: grid;
  grid-template-columns: 200px 1fr;
  gap: 30px;
  margin-bottom: 40px;
  align-items: start;
}

.score-card {
  text-align: center;
  padding: 30px 20px;
  border-radius: 12px;
  color: white;
  position: relative;
}

.score-card.excellent {
  background: linear-gradient(135deg, #28a745, #20c997);
}

.score-card.good {
  background: linear-gradient(135deg, #007bff, #6610f2);
}

.score-card.fair {
  background: linear-gradient(135deg, #ffc107, #fd7e14);
}

.score-card.poor {
  background: linear-gradient(135deg, #dc3545, #e83e8c);
}

.score-value {
  font-size: 48px;
  font-weight: bold;
  line-height: 1;
}

.score-label {
  font-size: 16px;
  margin: 10px 0 5px 0;
}

.score-max {
  font-size: 18px;
  opacity: 0.8;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 15px;
}

.metric-card {
  text-align: center;
  padding: 20px 15px;
  border-radius: 8px;
  color: white;
}

.metric-card.passed {
  background-color: #28a745;
}

.metric-card.failed {
  background-color: #dc3545;
}

.metric-card.warnings {
  background-color: #ffc107;
  color: #212529;
}

.metric-card.total {
  background-color: #6c757d;
}

.metric-value {
  font-size: 24px;
  font-weight: bold;
}

.metric-label {
  font-size: 12px;
  margin-top: 5px;
  opacity: 0.9;
}

.validation-sections {
  display: flex;
  flex-direction: column;
  gap: 30px;
}

.section {
  background: #f6f8fa;
  border-radius: 8px;
  padding: 25px;
  border: 1px solid #e1e5e9;
}

.section h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
  color: #24292f;
}

.rule-description {
  color: #656d76;
  font-size: 14px;
  margin-bottom: 20px;
  font-style: italic;
}

.issues-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.issue-item {
  border-radius: 6px;
  padding: 15px;
  border-left: 4px solid;
}

.issue-item.error {
  background: #ffebe9;
  border-left-color: #cf222e;
}

.issue-item.warning {
  background: #fff8c5;
  border-left-color: #d29922;
}

.issue-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
  font-weight: 500;
}

.severity-icon {
  font-size: 16px;
}

.issue-module {
  font-family: 'SF Mono', Monaco, monospace;
  background: rgba(255, 255, 255, 0.7);
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13px;
}

.issue-dependency {
  font-family: 'SF Mono', Monaco, monospace;
  color: #656d76;
  font-size: 13px;
}

.issue-message {
  color: #24292f;
  font-size: 14px;
  line-height: 1.4;
}

.actions {
  display: flex;
  gap: 15px;
  margin-top: 40px;
  justify-content: center;
  flex-wrap: wrap;
}

.btn-primary, .btn-secondary {
  padding: 10px 20px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s ease;
}

.btn-primary {
  background: #0969da;
  color: white;
}

.btn-primary:hover {
  background: #0860ca;
}

.btn-secondary {
  background: #f6f8fa;
  color: #24292f;
  border: 1px solid #d1d9e0;
}

.btn-secondary:hover {
  background: #f3f4f6;
}

@media (max-width: 768px) {
  .health-overview {
    grid-template-columns: 1fr;
    text-align: center;
  }
  
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .dashboard-header {
    flex-direction: column;
    text-align: center;
  }
  
  .actions {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>