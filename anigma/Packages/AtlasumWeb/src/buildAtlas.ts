/**
 * Atlasum Build Script
 *
 * Generates the Anigma Atlas index-first experience plus JSON artifacts.
 *
 * Usage: npm run build
 * Outputs:
 *   - ../../Docs/Atlas/anigma-atlas.html
 *   - ../../Docs/Atlas/anigma-atlas.json
 *   - ../../Docs/Atlas/anigma-atlas-search.json
 */

import { Transformer } from 'markmap-lib';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const REPO_ROOT = path.resolve(__dirname, '../../..');
const ATLAS_SOURCE = path.resolve(REPO_ROOT, 'Docs/Atlas/anigma-atlas.md');
const ATLAS_OUTPUT = path.resolve(REPO_ROOT, 'Docs/Atlas/anigma-atlas.html');
const ATLAS_JSON = path.resolve(REPO_ROOT, 'Docs/Atlas/atlas.json');
const ATLAS_SEARCH = path.resolve(REPO_ROOT, 'Docs/Atlas/search.json');
const ATLAS_JSON_LEGACY = path.resolve(REPO_ROOT, 'Docs/Atlas/anigma-atlas.json');
const ATLAS_SEARCH_LEGACY = path.resolve(REPO_ROOT, 'Docs/Atlas/anigma-atlas-search.json');

type DocLink = {
  label: string;
  url: string;
};

type AtlasNode = {
  id: string;
  title: string;
  summary: string;
  layer: string;
  domain: string;
  status: string;
  tags: string[];
  docs: DocLink[];
  parents: string[];
  children: string[];
  related: string[];
};

type AtlasData = {
  generatedAt: string;
  rootId: string;
  nodes: AtlasNode[];
};

type SearchEntry = {
  id: string;
  title: string;
  summary: string;
  layer: string;
  domain: string;
  status: string;
  tags: string[];
};

const LAYER_MAP: Record<string, string> = {
  'Core Foundations': 'Core',
  'Capability Modules': 'Capability Module',
  'Apps & UI Shells': 'App Shell',
  'Daemons & Services': 'Service',
  'CLI Tools': 'CLI',
  'ML & Workers': 'Core',
  'Tooling & Interop': 'Tooling',
  'Governance': 'Governance',
  'Docs': 'Docs',
  'Tools': 'Tooling',
};

const DOMAIN_KEYWORDS: Array<{ regex: RegExp; domain: string }> = [
  { regex: /governance|policy|constitution|doctrine|praxis/i, domain: 'Governance' },
  { regex: /job|workflow|scheduler|pipeline/i, domain: 'Jobs' },
  { regex: /ml|inference|vector|embedding|model/i, domain: 'ML' },
  { regex: /storage|database|sqlite|cache/i, domain: 'Storage' },
  { regex: /ui|app|client|design|shell/i, domain: 'UI' },
  { regex: /daemon|server|execution|worker/i, domain: 'Execution' },
  { regex: /tool|build|test|harness|cli/i, domain: 'Tooling' },
  { regex: /docs|roadmap|adr|techdebt|runbook|schema/i, domain: 'Docs' },
];

function stripTags(value: string): string {
  return value.replace(/<[^>]*>/g, '').trim();
}

function splitTitleSummary(value: string): { title: string; summary: string } {
  const clean = stripTags(value);
  const separators = ['—', ' - '];
  for (const separator of separators) {
    if (clean.includes(separator)) {
      const parts = clean.split(separator);
      const title = parts[0].trim();
      const summary = parts.slice(1).join(separator).trim();
      return { title, summary };
    }
  }
  return { title: clean.trim(), summary: '' };
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

function uniqueId(baseId: string, existing: Set<string>): string {
  let id = baseId || 'node';
  let counter = 2;
  while (existing.has(id)) {
    id = `${baseId}-${counter}`;
    counter += 1;
  }
  existing.add(id);
  return id;
}

function getLayer(topCategory: string): string {
  return LAYER_MAP[topCategory] || 'Core';
}

function getDomain(title: string, topCategory: string): string {
  for (const entry of DOMAIN_KEYWORDS) {
    if (entry.regex.test(title) || entry.regex.test(topCategory)) {
      return entry.domain;
    }
  }
  return topCategory || 'Platform';
}

function getStatus(text: string): string {
  const lower = text.toLowerCase();
  if (lower.includes('stub') || lower.includes('placeholder') || lower.includes('techdebt')) {
    return 'Stubbed';
  }
  if (lower.includes('experimental') || lower.includes('in progress')) {
    return 'In progress';
  }
  return 'Stable';
}

function getDocs(topCategory: string): DocLink[] {
  if (topCategory === 'Governance') {
    return [{ label: 'Governance model', url: '../docs/governance/index.html' }];
  }
  if (topCategory === 'Docs') {
    return [{ label: 'Documentation index', url: '../docs/index.html' }];
  }
  return [{ label: 'Documentation', url: '../docs/index.html' }];
}

function buildAtlasData(markdown: string): AtlasData {
  const transformer = new Transformer();
  const { root } = transformer.transform(markdown);

  const nodes: AtlasNode[] = [];
  const ids = new Set<string>();

  function walk(node: any, parentId: string | null, pathTitles: string[]): AtlasNode {
    const { title, summary } = splitTitleSummary(node.content || '');
    const currentPath = [...pathTitles, title || 'Untitled'];
    const baseId = currentPath.map(slugify).filter(Boolean).join('--');
    const id = uniqueId(baseId, ids);
    const topCategory = currentPath.length > 1 ? currentPath[1] : title;
    const layer = getLayer(topCategory);
    const domain = getDomain(title, topCategory);
    const status = getStatus(`${title} ${summary}`);
    const docs = getDocs(topCategory);
    const tags = [layer, domain, status].filter(Boolean);

    const atlasNode: AtlasNode = {
      id,
      title: title || 'Untitled',
      summary,
      layer,
      domain,
      status,
      tags,
      docs,
      parents: parentId ? [parentId] : [],
      children: [],
      related: [],
    };

    nodes.push(atlasNode);

    if (node.children && node.children.length) {
      node.children.forEach((child: any) => {
        const childNode = walk(child, id, currentPath);
        atlasNode.children.push(childNode.id);
      });
    }

    return atlasNode;
  }

  const rootNode = walk(root, null, []);

  return {
    generatedAt: new Date().toISOString(),
    rootId: rootNode.id,
    nodes,
  };
}

function buildSearchIndex(atlasData: AtlasData): SearchEntry[] {
  return atlasData.nodes.map((node) => ({
    id: node.id,
    title: node.title,
    summary: node.summary,
    layer: node.layer,
    domain: node.domain,
    status: node.status,
    tags: node.tags,
  }));
}

function escapeJsonForHtml(value: unknown): string {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

function generateHTML(atlasData: AtlasData, searchData: SearchEntry[]): string {
  const atlasJson = escapeJsonForHtml(atlasData);
  const searchJson = escapeJsonForHtml(searchData);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
  <meta name="description" content="Anigma Atlas - Interactive visual index of the Anigma platform">
  <meta name="application-name" content="Anigma Atlas">
  <meta name="apple-mobile-web-app-title" content="Anigma Atlas">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#f4f0e8">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta name="format-detection" content="telephone=no">
  <meta property="og:title" content="Anigma Atlas">
  <meta property="og:description" content="Interactive visual index of the Anigma platform">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://anigma.app/atlas/">
  <meta property="og:image" content="https://anigma.app/images/favicon.png">
  <meta property="og:site_name" content="anigma.app">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="Anigma Atlas">
  <meta name="twitter:description" content="Interactive visual index of the Anigma platform">
  <title>Anigma Atlas</title>
  <style>
    @import url("https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700&family=Montserrat:wght@600;700&display=swap");

    * { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --bg: #f4f0e8;
      --panel: #fbfaf7;
      --ink: #1f1e1a;
      --muted: #4c463c;
      --border: rgba(31, 30, 26, 0.12);
      --accent: #4e5b2a;
      --accent-soft: #c9d2a8;
      --card-radius: 14px;
      --shadow: 0 12px 28px rgba(31, 30, 26, 0.12);
    }

    html, body {
      height: 100%;
    }

    body {
      font-family: "Manrope", "Helvetica Neue", Arial, sans-serif;
      background: var(--bg);
      color: var(--ink);
      display: flex;
      flex-direction: column;
      min-height: 100%;
      overflow: hidden;
    }

    header {
      position: sticky;
      top: 0;
      z-index: 10;
      background: rgba(244, 240, 232, 0.94);
      backdrop-filter: saturate(140%) blur(10px);
      border-bottom: 1px solid var(--border);
      padding: 16px 24px 14px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .header-row {
      display: flex;
      justify-content: space-between;
      gap: 24px;
      align-items: center;
    }

    .header-title {
      font-family: "Montserrat", "Helvetica Neue", Arial, sans-serif;
      font-size: 16px;
      letter-spacing: 0.2em;
      text-transform: uppercase;
    }

    .header-subtitle {
      margin-top: 6px;
      color: var(--muted);
      font-size: 14px;
    }

    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .search input {
      width: 260px;
      max-width: 40vw;
      padding: 9px 14px;
      border-radius: 999px;
      border: 1px solid var(--border);
      background: var(--panel);
      font-size: 14px;
      color: var(--ink);
    }

    .view-toggle {
      display: inline-flex;
      gap: 6px;
      padding: 4px;
      border-radius: 999px;
      background: var(--panel);
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
    }

    .view-toggle button {
      border: none;
      background: transparent;
      padding: 6px 12px;
      border-radius: 999px;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      cursor: pointer;
      color: var(--muted);
    }

    .view-toggle button.is-active {
      background: var(--accent);
      color: #fff;
    }

    #app {
      flex: 1 1 auto;
      display: grid;
      grid-template-columns: minmax(0, 1fr) 420px;
      min-height: 0;
    }

    #index-panel {
      display: flex;
      flex-direction: column;
      min-height: 0;
      padding: 18px 22px 24px;
      gap: 12px;
    }

    #filters {
      display: flex;
      flex-wrap: wrap;
      gap: 12px 16px;
    }

    .filter-group {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }

    .filter-label {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.14em;
      color: var(--muted);
    }

    .filter-chip {
      border: 1px solid var(--border);
      background: var(--panel);
      color: var(--ink);
      padding: 6px 10px;
      border-radius: 999px;
      font-size: 11px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      cursor: pointer;
    }

    .filter-chip.is-active {
      background: var(--accent-soft);
      border-color: var(--accent);
      color: var(--accent);
    }

    #results-meta {
      display: flex;
      justify-content: space-between;
      align-items: center;
      color: var(--muted);
      font-size: 13px;
    }

    #atlas-list {
      list-style: none;
      display: grid;
      gap: 10px;
      padding: 0;
      margin: 0;
      overflow-y: auto;
      flex: 1 1 auto;
      min-height: 0;
    }

    .atlas-row {
      width: 100%;
      text-align: left;
      border: 1px solid var(--border);
      background: var(--panel);
      border-radius: var(--card-radius);
      padding: 12px 14px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      cursor: pointer;
      box-shadow: 0 6px 16px rgba(31, 30, 26, 0.08);
    }

    .atlas-row.is-active {
      border-color: var(--accent);
      box-shadow: 0 0 0 2px rgba(78, 91, 42, 0.2);
    }

    .row-title {
      font-size: 15px;
      font-weight: 600;
    }

    .row-summary {
      font-size: 13px;
      color: var(--muted);
      line-height: 1.4;
    }

    .row-tags {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }

    .row-tag {
      font-size: 10px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      padding: 2px 8px;
      border-radius: 999px;
      border: 1px solid var(--border);
      color: var(--muted);
    }

    #graph-view {
      display: none;
      flex: 1 1 auto;
      min-height: 0;
      flex-direction: column;
      gap: 12px;
    }

    #graph-view.is-active {
      display: flex;
    }

    .graph-controls {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 13px;
      color: var(--muted);
    }

    .graph-controls input[type="range"] {
      width: 120px;
    }

    #graph-canvas {
      width: 100%;
      flex: 1 1 auto;
      border-radius: var(--card-radius);
      border: 1px solid var(--border);
      background: var(--panel);
    }

    #graph-empty {
      font-size: 13px;
      color: var(--muted);
      text-align: center;
      padding: 12px 0;
    }

    .is-hidden {
      display: none;
    }

    #panel {
      background: var(--panel);
      border-left: 1px solid var(--border);
      padding: 20px 24px;
      overflow-y: auto;
    }

    .panel-section {
      margin-bottom: 18px;
    }

    .panel-label {
      font-size: 11px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: 6px;
    }

    .panel-title {
      font-size: 22px;
      margin-bottom: 8px;
    }

    .panel-desc {
      color: var(--muted);
      line-height: 1.5;
      font-size: 14px;
    }

    .panel-pill {
      display: inline-flex;
      align-items: center;
      padding: 6px 12px;
      border-radius: 999px;
      border: 1px solid var(--border);
      background: var(--bg);
      font-size: 11px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-right: 8px;
    }

    .panel-links a,
    .panel-related button {
      color: var(--accent);
      text-decoration: none;
      border-bottom: 1px solid rgba(78, 91, 42, 0.4);
      background: none;
      border: none;
      padding: 0;
      font-size: 13px;
      cursor: pointer;
    }

    .panel-related {
      list-style: none;
      padding: 0;
      display: grid;
      gap: 8px;
    }

    .related-item {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .related-kind {
      font-size: 10px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
      border: 1px solid var(--border);
      padding: 2px 8px;
      border-radius: 999px;
    }

    @media (max-width: 1100px) {
      #app {
        grid-template-columns: 1fr;
        grid-template-rows: minmax(0, 1fr) auto;
      }

      #panel {
        border-left: none;
        border-top: 1px solid var(--border);
        max-height: 45vh;
      }

      .header-row {
        flex-direction: column;
        align-items: flex-start;
      }

      .header-actions {
        width: 100%;
        justify-content: space-between;
        flex-wrap: wrap;
      }

      .search input {
        width: min(100%, 320px);
      }
    }

    @media (prefers-reduced-motion: reduce) {
      * {
        animation: none !important;
        transition: none !important;
      }
    }
  </style>
</head>
<body>
  <header>
    <div class="header-row">
      <div>
        <div class="header-title">ANIGMA ATLAS</div>
        <div class="header-subtitle">A visual index of Anigma's governed architecture.</div>
      </div>
      <div class="header-actions">
        <div class="search">
          <input id="atlas-search" type="search" placeholder="Search (Cmd+K)" aria-label="Search atlas" />
        </div>
        <div class="view-toggle" role="tablist" aria-label="Atlas views">
          <button type="button" class="is-active" data-view="index" role="tab">Index</button>
          <button type="button" data-view="graph" role="tab">Relationships</button>
        </div>
      </div>
    </div>
  </header>

  <main id="app">
    <section id="index-panel">
      <div id="filters">
        <div class="filter-group" data-filter="layer">
          <span class="filter-label">Layer</span>
          <div class="filter-chips"></div>
        </div>
        <div class="filter-group" data-filter="status">
          <span class="filter-label">Status</span>
          <div class="filter-chips"></div>
        </div>
        <div class="filter-group" data-filter="domain">
          <span class="filter-label">Domain</span>
          <div class="filter-chips"></div>
        </div>
      </div>

      <div id="results-meta">
        <span id="results-count">0 results</span>
        <span id="selection-hint">Select a node to see details.</span>
      </div>

      <div id="index-view">
        <ul id="atlas-list" aria-label="Atlas index"></ul>
      </div>

      <div id="graph-view">
        <div class="graph-controls">
          <span>Neighborhood hops</span>
          <input id="graph-hops" type="range" min="1" max="2" step="1" value="1" />
          <span id="graph-hops-value">1</span>
        </div>
        <div id="graph-empty">Select a node to see relationships.</div>
        <svg id="graph-canvas" role="img" aria-label="Neighborhood graph"></svg>
      </div>
    </section>

    <aside id="panel" aria-live="polite">
      <div class="panel-section">
        <div class="panel-label">Selected</div>
        <div class="panel-title" id="panel-title">Anigma Atlas</div>
        <div class="panel-desc" id="panel-desc">Select a node to explore the architecture.</div>
      </div>
      <div class="panel-section">
        <div class="panel-label">Layer</div>
        <div class="panel-pill" id="panel-layer">-</div>
        <div class="panel-pill" id="panel-domain">-</div>
      </div>
      <div class="panel-section">
        <div class="panel-label">Status</div>
        <div class="panel-pill" id="panel-status">-</div>
      </div>
      <div class="panel-section">
        <div class="panel-label">Primary docs</div>
        <div class="panel-links" id="panel-docs">No docs linked yet.</div>
      </div>
      <div class="panel-section">
        <div class="panel-label">Related nodes</div>
        <ul class="panel-related" id="panel-related"></ul>
      </div>
    </aside>
  </main>

  <script type="application/json" id="atlas-data">${atlasJson}</script>
  <script type="application/json" id="atlas-search">${searchJson}</script>

  <script>
    const atlasData = JSON.parse(document.getElementById('atlas-data').textContent || '{}');
    const searchData = JSON.parse(document.getElementById('atlas-search').textContent || '[]');

    const nodeById = new Map((atlasData.nodes || []).map((node) => [node.id, node]));

    const state = {
      view: 'index',
      query: '',
      selectedId: atlasData.rootId || null,
      hops: 1,
      filters: {
        layer: new Set(),
        status: new Set(),
        domain: new Set(),
      }
    };

    const filterOptions = {
      layer: Array.from(new Set(searchData.map((node) => node.layer))).sort(),
      status: Array.from(new Set(searchData.map((node) => node.status))).sort(),
      domain: Array.from(new Set(searchData.map((node) => node.domain))).sort(),
    };

    const atlasList = document.getElementById('atlas-list');
    const resultsCount = document.getElementById('results-count');
    const selectionHint = document.getElementById('selection-hint');
    const searchInput = document.getElementById('atlas-search');
    const indexView = document.getElementById('index-view');
    const panelTitle = document.getElementById('panel-title');
    const panelDesc = document.getElementById('panel-desc');
    const panelLayer = document.getElementById('panel-layer');
    const panelDomain = document.getElementById('panel-domain');
    const panelStatus = document.getElementById('panel-status');
    const panelDocs = document.getElementById('panel-docs');
    const panelRelated = document.getElementById('panel-related');
    const graphView = document.getElementById('graph-view');
    const graphEmpty = document.getElementById('graph-empty');
    const graphCanvas = document.getElementById('graph-canvas');
    const graphHops = document.getElementById('graph-hops');
    const graphHopsValue = document.getElementById('graph-hops-value');

    function updateHash() {
      const params = new URLSearchParams();
      if (state.selectedId) params.set('id', state.selectedId);
      params.set('view', state.view);
      params.set('hops', String(state.hops));
      if (state.query) params.set('q', state.query);
      if (state.filters.layer.size) params.set('layer', Array.from(state.filters.layer).join(','));
      if (state.filters.status.size) params.set('status', Array.from(state.filters.status).join(','));
      if (state.filters.domain.size) params.set('domain', Array.from(state.filters.domain).join(','));
      history.replaceState(null, '', '#' + params.toString());
    }

    function restoreFromHash() {
      if (!location.hash) return;
      const params = new URLSearchParams(location.hash.replace('#', ''));
      if (params.get('id')) state.selectedId = params.get('id');
      if (params.get('view')) state.view = params.get('view');
      if (params.get('q')) state.query = params.get('q');
      if (params.get('hops')) state.hops = Number(params.get('hops')) || 1;
      ['layer', 'status', 'domain'].forEach((key) => {
        const value = params.get(key);
        if (value) {
          state.filters[key] = new Set(value.split(',').filter(Boolean));
        }
      });
    }

    function renderFilters() {
      document.querySelectorAll('.filter-group').forEach((group) => {
        const filterKey = group.dataset.filter;
        const chipsContainer = group.querySelector('.filter-chips');
        chipsContainer.innerHTML = '';
        filterOptions[filterKey].forEach((value) => {
          const button = document.createElement('button');
          button.type = 'button';
          button.className = 'filter-chip' + (state.filters[filterKey].has(value) ? ' is-active' : '');
          button.textContent = value;
          button.addEventListener('click', () => {
            if (state.filters[filterKey].has(value)) {
              state.filters[filterKey].delete(value);
            } else {
              state.filters[filterKey].add(value);
            }
            renderAll();
          });
          chipsContainer.appendChild(button);
        });
      });
    }

    function matchesFilters(node) {
      const query = state.query.toLowerCase();
      if (state.filters.layer.size && !state.filters.layer.has(node.layer)) return false;
      if (state.filters.status.size && !state.filters.status.has(node.status)) return false;
      if (state.filters.domain.size && !state.filters.domain.has(node.domain)) return false;
      if (!query) return true;
      const haystack = [node.title, node.summary, ...(node.tags || [])].join(' ').toLowerCase();
      return haystack.includes(query);
    }

    function renderList() {
      const filtered = searchData.filter(matchesFilters);
      resultsCount.textContent = filtered.length + ' results';
      atlasList.innerHTML = '';
      const fragment = document.createDocumentFragment();
      filtered.forEach((node) => {
        const li = document.createElement('li');
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'atlas-row' + (state.selectedId === node.id ? ' is-active' : '');
        const title = document.createElement('div');
        title.className = 'row-title';
        title.textContent = node.title;
        const summary = document.createElement('div');
        summary.className = 'row-summary';
        summary.textContent = node.summary || 'No summary yet.';
        const tags = document.createElement('div');
        tags.className = 'row-tags';
        [node.layer, node.domain, node.status].forEach((tagText) => {
          const tag = document.createElement('span');
          tag.className = 'row-tag';
          tag.textContent = tagText;
          tags.appendChild(tag);
        });
        button.appendChild(title);
        button.appendChild(summary);
        button.appendChild(tags);
        button.addEventListener('click', () => selectNode(node.id));
        li.appendChild(button);
        fragment.appendChild(li);
      });
      atlasList.appendChild(fragment);
    }

    function renderPanel(node) {
      if (!node) return;
      panelTitle.textContent = node.title;
      panelDesc.textContent = node.summary || 'No description yet.';
      panelLayer.textContent = node.layer;
      panelDomain.textContent = node.domain;
      panelStatus.textContent = node.status;

      panelDocs.innerHTML = '';
      if (!node.docs || !node.docs.length) {
        panelDocs.textContent = 'No docs linked yet.';
      } else {
        node.docs.forEach((doc) => {
          const link = document.createElement('a');
          link.href = doc.url;
          link.target = '_blank';
          link.rel = 'noopener';
          link.textContent = doc.label;
          panelDocs.appendChild(link);
        });
      }

      panelRelated.innerHTML = '';
      const relatedItems = [];
      node.parents.forEach((id) => relatedItems.push({ id, kind: 'Parent' }));
      node.children.forEach((id) => relatedItems.push({ id, kind: 'Child' }));
      node.related.forEach((id) => relatedItems.push({ id, kind: 'Related' }));

      if (!relatedItems.length) {
        const empty = document.createElement('li');
        empty.textContent = 'No related nodes.';
        panelRelated.appendChild(empty);
      } else {
        relatedItems.forEach((item) => {
          const li = document.createElement('li');
          li.className = 'related-item';
          const kind = document.createElement('span');
          kind.className = 'related-kind';
          kind.textContent = item.kind;
          const button = document.createElement('button');
          button.type = 'button';
          const relatedNode = nodeById.get(item.id);
          button.textContent = relatedNode ? relatedNode.title : item.id;
          button.addEventListener('click', () => selectNode(item.id));
          li.appendChild(kind);
          li.appendChild(button);
          panelRelated.appendChild(li);
        });
      }
    }

    function selectNode(nodeId) {
      state.selectedId = nodeId;
      const node = nodeById.get(nodeId);
      selectionHint.textContent = node ? 'Selected: ' + node.title : 'Select a node to see details.';
      renderList();
      renderPanel(node);
      renderGraph();
      updateHash();
    }

    function setView(view) {
      state.view = view;
      document.querySelectorAll('.view-toggle button').forEach((button) => {
        button.classList.toggle('is-active', button.dataset.view === view);
      });
      graphView.classList.toggle('is-active', view === 'graph');
      indexView.classList.toggle('is-hidden', view === 'graph');
      updateHash();
      renderGraph();
    }

    function getNeighborhoodIds(nodeId, hops) {
      const visited = new Set();
      let frontier = [nodeId];
      visited.add(nodeId);
      for (let i = 0; i < hops; i += 1) {
        const next = [];
        frontier.forEach((id) => {
          const node = nodeById.get(id);
          if (!node) return;
          [...node.parents, ...node.children, ...node.related].forEach((neighbor) => {
            if (!visited.has(neighbor)) {
              visited.add(neighbor);
              next.push(neighbor);
            }
          });
        });
        frontier = next;
      }
      return Array.from(visited);
    }

    function renderGraph() {
      if (state.view !== 'graph') return;
      const node = nodeById.get(state.selectedId);
      graphCanvas.innerHTML = '';
      if (graphEmpty) graphEmpty.style.display = node ? 'none' : 'block';
      if (!node) return;

      const width = graphCanvas.clientWidth || 800;
      const height = graphCanvas.clientHeight || 400;
      const svgNS = 'http://www.w3.org/2000/svg';
      graphCanvas.setAttribute('viewBox', '0 0 ' + width + ' ' + height);

      const lanes = ['Core', 'Capability', 'Shell'];
      const laneMap = {
        'Core': 'Core',
        'Governance': 'Core',
        'Docs': 'Core',
        'Tooling': 'Core',
        'Capability Module': 'Capability',
        'CLI': 'Capability',
        'Service': 'Shell',
        'App Shell': 'Shell',
      };

      const neighborhoodIds = getNeighborhoodIds(node.id, state.hops);
      const laneNodes = { Core: [], Capability: [], Shell: [] };
      neighborhoodIds.forEach((id) => {
        const n = nodeById.get(id);
        if (!n) return;
        const lane = laneMap[n.layer] || 'Core';
        laneNodes[lane].push(n);
      });

      lanes.forEach((lane, index) => {
        const rect = document.createElementNS(svgNS, 'rect');
        rect.setAttribute('x', String(index * (width / 3)));
        rect.setAttribute('y', '0');
        rect.setAttribute('width', String(width / 3));
        rect.setAttribute('height', String(height));
        rect.setAttribute('fill', index % 2 === 0 ? '#f9f6ef' : '#f4efe6');
        graphCanvas.appendChild(rect);

        const label = document.createElementNS(svgNS, 'text');
        label.setAttribute('x', String(index * (width / 3) + 16));
        label.setAttribute('y', '24');
        label.setAttribute('fill', '#6b6458');
        label.setAttribute('font-size', '12');
        label.setAttribute('letter-spacing', '2');
        label.textContent = lane.toUpperCase();
        graphCanvas.appendChild(label);
      });

      const positions = new Map();
      lanes.forEach((lane, index) => {
        const nodesInLane = laneNodes[lane];
        const laneWidth = width / 3;
        const padding = 50;
        const availableHeight = height - padding * 2;
        const spacing = nodesInLane.length ? availableHeight / (nodesInLane.length + 1) : availableHeight;
        nodesInLane.sort((a, b) => a.title.localeCompare(b.title)).forEach((n, idx) => {
          const x = index * laneWidth + laneWidth / 2;
          const y = padding + spacing * (idx + 1);
          positions.set(n.id, { x, y });
        });
      });

      const selectedPos = positions.get(node.id);
      if (selectedPos) {
        neighborhoodIds.forEach((id) => {
          if (id === node.id) return;
          const targetPos = positions.get(id);
          if (!targetPos) return;
          const line = document.createElementNS(svgNS, 'line');
          line.setAttribute('x1', String(selectedPos.x));
          line.setAttribute('y1', String(selectedPos.y));
          line.setAttribute('x2', String(targetPos.x));
          line.setAttribute('y2', String(targetPos.y));
          line.setAttribute('stroke', '#b9ad9d');
          line.setAttribute('stroke-width', '1.5');
          graphCanvas.appendChild(line);
        });
      }

      neighborhoodIds.forEach((id) => {
        const n = nodeById.get(id);
        const pos = positions.get(id);
        if (!n || !pos) return;
        const group = document.createElementNS(svgNS, 'g');
        const rect = document.createElementNS(svgNS, 'rect');
        const widthRect = 160;
        const heightRect = 46;
        rect.setAttribute('x', String(pos.x - widthRect / 2));
        rect.setAttribute('y', String(pos.y - heightRect / 2));
        rect.setAttribute('width', String(widthRect));
        rect.setAttribute('height', String(heightRect));
        rect.setAttribute('rx', '10');
        rect.setAttribute('fill', id === node.id ? '#4e5b2a' : '#fffaf3');
        rect.setAttribute('stroke', id === node.id ? '#4e5b2a' : '#b9ad9d');
        group.appendChild(rect);

        const text = document.createElementNS(svgNS, 'text');
        text.setAttribute('x', String(pos.x));
        text.setAttribute('y', String(pos.y + 4));
        text.setAttribute('font-size', '12');
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('fill', id === node.id ? '#fffaf3' : '#1f1e1a');
        const label = n.title.length > 22 ? n.title.slice(0, 21) + '...' : n.title;
        text.textContent = label;
        group.appendChild(text);

        group.addEventListener('click', () => selectNode(id));
        graphCanvas.appendChild(group);
      });
    }

    function renderAll() {
      renderFilters();
      renderList();
      renderPanel(nodeById.get(state.selectedId));
      setView(state.view);
      graphHops.value = String(state.hops);
      graphHopsValue.textContent = String(state.hops);
      searchInput.value = state.query;
      updateHash();
    }

    restoreFromHash();
    renderAll();

    searchInput.addEventListener('input', (event) => {
      state.query = event.target.value || '';
      renderList();
      updateHash();
    });

    document.querySelectorAll('.view-toggle button').forEach((button) => {
      button.addEventListener('click', () => setView(button.dataset.view));
    });

    graphHops.addEventListener('input', (event) => {
      state.hops = Number(event.target.value) || 1;
      graphHopsValue.textContent = String(state.hops);
      renderGraph();
      updateHash();
    });

    document.addEventListener('keydown', (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchInput.focus();
        searchInput.select();
      }
    });
  </script>
</body>
</html>`;
}

async function buildAtlas(): Promise<void> {
  console.log('🗺️  Atlasum: Building Anigma Atlas...');

  if (!fs.existsSync(ATLAS_SOURCE)) {
    console.error(`❌ Atlas source not found: ${ATLAS_SOURCE}`);
    process.exit(1);
  }

  const markdown = fs.readFileSync(ATLAS_SOURCE, 'utf-8');
  console.log(`📄 Read ${markdown.length} bytes from atlas source`);

  const atlasData = buildAtlasData(markdown);
  const searchData = buildSearchIndex(atlasData);
  const html = generateHTML(atlasData, searchData);

  fs.writeFileSync(ATLAS_OUTPUT, html, 'utf-8');
  fs.writeFileSync(ATLAS_JSON, JSON.stringify(atlasData, null, 2), 'utf-8');
  fs.writeFileSync(ATLAS_SEARCH, JSON.stringify(searchData, null, 2), 'utf-8');
  fs.writeFileSync(ATLAS_JSON_LEGACY, JSON.stringify(atlasData, null, 2), 'utf-8');
  fs.writeFileSync(ATLAS_SEARCH_LEGACY, JSON.stringify(searchData, null, 2), 'utf-8');

  console.log(`✅ Generated: ${ATLAS_OUTPUT}`);
  console.log(`✅ Generated: ${ATLAS_JSON}`);
  console.log(`✅ Generated: ${ATLAS_SEARCH}`);
  console.log(`✅ Generated: ${ATLAS_JSON_LEGACY}`);
  console.log(`✅ Generated: ${ATLAS_SEARCH_LEGACY}`);
  console.log(`📊 Output size: ${(html.length / 1024).toFixed(1)} KB`);
}

buildAtlas().catch((err) => {
  console.error('❌ Build failed:', err);
  process.exit(1);
});
