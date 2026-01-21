# Anigma Dashboard

Web-based ops dashboard for the Anigma control plane.

## Purpose

Browser-accessible admin UI for:
- Viewing node status, health, and load
- Monitoring job queues and execution
- Visualizing workflows and ECS systems
- Viewing logs and metrics

Served by the Harmonia daemon at `/admin`.

## Stack

| Library | License | Purpose |
|---------|---------|---------|
| React 18 | MIT | UI framework |
| Tailwind CSS | MIT | Styling |
| Headless UI | MIT | Accessible primitives |
| React Flow | MIT | Workflow/DAG visualization |
| Recharts | MIT | Charts and metrics |
| Zustand | MIT | State management |
| React Query | MIT | Data fetching/caching |

## Build

```bash
npm install
npm run build
```

Output: `dist/` folder with static assets.

## Deployment

Copy `dist/` to daemon's static file directory.
Daemon serves at `http://localhost:PORT/admin/`.

## Features

### Node Overview
- List of active Anigma nodes
- CPU/RAM/GPU utilization per node
- Health status indicators

### Job Queue
- Pending/running/completed jobs
- Priority queue visualization
- Job detail view with entity refs

### Workflow Viewer
- React Flow graph of registered workflows
- System dependencies and execution order
- Click system to see component read/write sets

### Metrics
- Job throughput over time
- Latency histograms
- Error rates by job type

### Logs
- Streaming logs via WebSocket
- Filter by level, category, node
- Search and time range

## API Contract

Dashboard expects these endpoints from the daemon:

```
GET  /api/nodes           # List nodes with health
GET  /api/jobs            # List jobs with filters
GET  /api/jobs/:id        # Job details
GET  /api/workflows       # Registered workflows
GET  /api/metrics         # Aggregated metrics
WS   /api/logs            # Streaming logs
WS   /api/events          # Real-time job/node events
```

## File Structure

```
src/
├── main.tsx              # Entry point
├── App.tsx               # Router and layout
├── api/                  # API client and WebSocket
├── components/           # Reusable UI components
├── pages/
│   ├── Nodes.tsx
│   ├── Jobs.tsx
│   ├── Workflows.tsx
│   ├── Metrics.tsx
│   └── Logs.tsx
├── stores/               # Zustand stores
└── styles/               # Tailwind config
```
