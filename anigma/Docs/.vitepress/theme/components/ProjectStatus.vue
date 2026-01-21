<script setup lang="ts">
import { computed } from 'vue'
import { useData } from 'vitepress'

const data = useData()
const themeConfig = computed(() => data.value?.themeConfig ?? {})
const projectStatus = computed(() => themeConfig.value.projectStatus ?? {})
const docsLastUpdatedIso = computed(() => {
  const value = projectStatus.value.docsLastUpdated
  return value ? new Date(value).toISOString() : null
})
const stageName = computed(() => projectStatus.value.sigmaStage ?? 'Sigma stage not defined')
const stageDefinition = computed(() => projectStatus.value.stageDefinition ?? 'Details pending.')
const roadmapLinks = computed(() => projectStatus.value.roadmapLinks ?? [])
const phase2Details = computed(() => projectStatus.value.phase2 ?? null)
const artifactLink = computed(() => {
  const phase2 = phase2Details.value
  const lastRun = phase2?.lastRun
  if (!phase2?.artifactTemplate || !lastRun) return null
  return phase2.artifactTemplate
    .replace('{pipelineVersion}', lastRun.pipelineVersion)
    .replace('{inputHash}', lastRun.inputHash)
})
const traceLink = computed(() => {
  const phase2 = phase2Details.value
  const lastRun = phase2?.lastRun
  if (!phase2?.traceTemplate || !lastRun) return null
  return phase2.traceTemplate
    .replace('{pipelineVersion}', lastRun.pipelineVersion)
    .replace('{inputHash}', lastRun.inputHash)
})
const phase3Details = computed(() => projectStatus.value.phase3 ?? null)
const phase3ArtifactLink = computed(() => {
  const phase3 = phase3Details.value
  const lastRun = phase3?.lastRun
  if (!phase3) return null
  if (lastRun?.artifactPath) {
    return lastRun.artifactPath
  }
  if (phase3.artifactTemplate && lastRun?.timestamp) {
    return phase3.artifactTemplate.replace('{timestamp}', lastRun.timestamp)
  }
  return phase3.artifactTemplate ?? null
})
const phase4Details = computed(() => projectStatus.value.phase4 ?? null)
const phase4ArtifactLink = computed(() => {
  const phase4 = phase4Details.value
  const lastRun = phase4?.lastRun
  if (!phase4) return null
  if (lastRun?.artifactPath) {
    return lastRun.artifactPath
  }
  if (phase4.artifactTemplate && lastRun?.runId) {
    return phase4.artifactTemplate.replace('{runId}', lastRun.runId)
  }
  return phase4.artifactTemplate ?? null
})
const phase5Details = computed(() => projectStatus.value.phase5 ?? null)
const phase5DocLink = computed(() => phase5Details.value?.docPath ?? null)
const statusSource = computed(() => projectStatus.value.statusSource ?? '/status/status.json')
</script>

<template>
  <section class="project-status">
    <h2>Project Status</h2>
    <dl>
      <div>
        <dt>Docs last updated</dt>
        <dd>
          <span v-if="docsLastUpdatedIso">{{ docsLastUpdatedIso }}</span>
          <span v-else>Unknown (git info unavailable)</span>
        </dd>
      </div>
      <div>
        <dt>Sigma roadmap stage</dt>
        <dd>{{ stageName }}</dd>
      </div>
    </dl>
    <details class="project-status-details">
      <summary>Deep dive</summary>
      <p>{{ stageDefinition }}</p>
      <ul>
        <li v-for="link in roadmapLinks" :key="link.href">
          <a :href="link.href">{{ link.label }}</a>
        </li>
      </ul>
      <div v-if="phase2Details" class="phase2-section">
        <h3>Phase 2 pipeline</h3>
        <ul>
          <li>
            Runner: <a :href="phase2Details.runnerScript">{{ phase2Details.runnerScript }}</a>
          </li>
          <li>
            Spec: <code>{{ phase2Details.specPath }}</code>
          </li>
          <li v-if="artifactLink">
            Latest artifact: <a :href="artifactLink">{{ artifactLink }}</a>
          </li>
          <li v-else>
            Artifact pattern: <code>{{ phase2Details.artifactTemplate }}</code>
          </li>
          <li v-if="traceLink">
            Trace (replay source): <a :href="traceLink">{{ traceLink }}</a>
          </li>
        </ul>
        <div v-if="phase2Details.notes && phase2Details.notes.length" class="phase2-notes">
          <strong>Notes:</strong>
          <ul>
            <li v-for="note in phase2Details.notes" :key="note">{{ note }}</li>
          </ul>
        </div>
        </div>
        <p class="status-source">
          Source: <a :href="statusSource">{{ statusSource }}</a>
        </p>
      </details>

      <details v-if="phase3Details" class="phase3-section">
        <summary>Phase 3 smoke harness</summary>
        <p>
          <a :href="phase3Details.harnessScript">Harmonia surface harness</a>
          records slot/session/request states and stores per-run reports.
        </p>
        <ul>
          <li v-if="phase3ArtifactLink">
            Latest report: <a :href="phase3ArtifactLink">{{ phase3ArtifactLink }}</a>
          </li>
          <li v-else-if="phase3Details.artifactTemplate">
            Report pattern: <code>{{ phase3Details.artifactTemplate }}</code>
          </li>
        </ul>
        <div v-if="phase3Details.notes && phase3Details.notes.length" class="phase3-notes">
          <strong>Notes:</strong>
          <ul>
            <li v-for="note in phase3Details.notes" :key="note">{{ note }}</li>
          </ul>
        </div>
      </details>

      <details v-if="phase4Details" class="phase4-section">
        <summary>Phase 4 operator shell</summary>
        <p>
          <a :href="phase4Details.runnerScript">AccessumFlow</a> orchestrates Diaplasion and Outlineum,
          records hashes, and writes a trace per run.
        </p>
        <ul>
          <li>
            Runner: <a :href="phase4Details.runnerScript">{{ phase4Details.runnerScript }}</a>
          </li>
          <li v-if="phase4ArtifactLink">
            Latest trace: <a :href="phase4ArtifactLink">{{ phase4ArtifactLink }}</a>
          </li>
          <li v-else-if="phase4Details.artifactTemplate">
            Trace pattern: <code>{{ phase4Details.artifactTemplate }}</code>
          </li>
        </ul>
        <div v-if="phase4Details.notes && phase4Details.notes.length" class="phase4-notes">
          <strong>Notes:</strong>
          <ul>
            <li v-for="note in phase4Details.notes" :key="note">{{ note }}</li>
          </ul>
        </div>
      </details>
      <details v-if="phase5Details" class="phase5-section">
        <summary>Phase 5 production hardening</summary>
        <p>
          <a :href="phase5Details.runnerScript">Daemon helper</a> persists Accessum runs, keeps structured logs, and can be wired into launchd.
        </p>
        <ul>
          <li>
            Admin command: <code>{{ phase5Details.adminCommand }}</code>
          </li>
          <li v-if="phase5Details.databasePath">
            Persistent database: <code>{{ phase5Details.databasePath }}</code>
          </li>
          <li v-if="phase5DocLink">
            Docs: <a :href="phase5DocLink">Packaging & daemon plan</a>
          </li>
        </ul>
        <div v-if="phase5Details.notes && phase5Details.notes.length" class="phase5-notes">
          <strong>Notes:</strong>
          <ul>
            <li v-for="note in phase5Details.notes" :key="note">{{ note }}</li>
          </ul>
        </div>
      </details>
    </section>
  </template>

<style scoped>
.project-status {
  margin: 2rem 0;
  padding: 1.25rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 0.5rem;
  background: var(--vp-canvas-bg);
}
.project-status h2 {
  margin-top: 0;
  margin-bottom: 1rem;
  font-size: 1.2rem;
}
.project-status dl {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin: 0;
}
.project-status dt {
  font-weight: 600;
}
.project-status dd {
  margin: 0;
  margin-left: 0;
  color: var(--vp-c-text-muted);
}
.project-status-details {
  margin-top: 1rem;
  border-top: 1px dashed var(--vp-c-divider);
  padding-top: 1rem;
}
.project-status-details summary {
  cursor: pointer;
  font-weight: 600;
  margin-bottom: 0.5rem;
}
.phase5-section {
  margin-top: 1rem;
  border-top: 1px dashed var(--vp-c-divider);
  padding-top: 1rem;
}
.phase5-section summary {
  cursor: pointer;
  font-weight: 600;
  margin-bottom: 0.5rem;
}
.project-status-details ul {
  margin: 0 0 0.5rem;
  padding-left: 1.25rem;
}
.status-source {
  font-size: 0.85rem;
  color: var(--vp-c-text-muted);
}
.phase2-section {
  margin-top: 1rem;
  padding: 0.75rem;
  background: var(--vp-canvas-bg);
  border-radius: 0.4rem;
  border: 1px solid var(--vp-c-divider);
}
.phase2-section h3 {
  margin: 0 0 0.5rem;
  font-size: 1rem;
}
.phase2-section ul {
  margin: 0;
  padding-left: 1.25rem;
}
.phase3-section,
.phase3-section summary {
  cursor: pointer;
  font-weight: 600;
}
.phase3-section {
  margin-top: 1rem;
  padding: 0.75rem;
  background: var(--vp-canvas-bg);
  border-radius: 0.4rem;
  border: 1px solid var(--vp-c-divider);
}
.phase3-notes {
  margin-top: 0.75rem;
}
.phase3-notes ul {
  margin: 0.25rem 0 0;
  padding-left: 1.25rem;
}
.phase2-notes {
  margin-top: 0.75rem;
}
.phase2-notes ul {
  margin: 0.25rem 0 0;
  padding-left: 1.25rem;
}
.phase4-section,
.phase4-section summary {
  cursor: pointer;
  font-weight: 600;
}
.phase4-section {
  margin-top: 1rem;
  padding: 0.75rem;
  background: var(--vp-canvas-bg);
  border-radius: 0.4rem;
  border: 1px solid var(--vp-c-divider);
}
.phase4-notes {
  margin-top: 0.75rem;
}
.phase4-notes ul {
  margin: 0.25rem 0 0;
  padding-left: 1.25rem;
}
</style>
