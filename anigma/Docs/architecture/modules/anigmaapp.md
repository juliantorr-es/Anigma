# AnigmaApp (Thin Client Projection)

## Overview

`AnigmaApp` is the macOS native SwiftUI application for the Anigma ecosystem. 

Architecturally, `AnigmaApp` is strictly a **Thin Client Adapter**. It does not own the database, it does not orchestrate AI models, and it does not contain business logic. Its sole responsibility is to project the state of the `anigmad` daemon to the user and forward user intents back to the daemon across an XPC/REST **seam**.

## Architectural Rules

1. **No Core Dependencies:** `AnigmaApp` is forbidden from importing `AnigmaCore`, `DatabaseCore`, `StorageCore`, or any ML inference libraries. 
2. **No Data Processing Libraries:** (Sealing the Visualization Seam) `AnigmaApp` is forbidden from importing `TabularData`, `Probably`, or doing raw statistical math. All aggregations, filtering, and variances must be computed by `anigmad`. The UI only renders pre-computed "Chart DTOs".
3. **Projection Only:** All state displayed in the app must be a deserialized projection of an IPC payload sent by `anigmad`. 
4. **Fragmented Stores:** The legacy monolithic `AppStore` is deprecated. State must be managed by domain-specific Projection Stores (`JobProjectionStore`, `ContextProjectionStore`) that handle specific XPC subscriptions.

## Interaction with `anigmad`
The UI is completely decoupled from the execution engine. If the `AnigmaApp` crashes or is closed, the `anigmad` daemon continues running jobs and saturated ML workloads in the background completely uninterrupted. When the app is reopened, it simply requests a fresh state projection from the daemon.
