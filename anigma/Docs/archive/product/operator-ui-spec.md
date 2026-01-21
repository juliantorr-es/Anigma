# Operator UI Specification: Anigma Control Center

The Anigma Control Center (ACC) is the envisioned administrative user interface designed for institutional operators, such as accessibility coordinators and IT personnel. This "pane of glass" provides a centralized overview and management capabilities for the Anigma Node, ensuring transparency, control, and auditability of all automated processes.

Its design prioritizes clarity, ease of use, and quick access to critical information, enabling effective oversight without requiring deep technical expertise.

## 1. Core Principles

*   **Transparency:** Clearly display the status and activity of the Anigma Node.
*   **Control:** Provide intuitive controls for managing jobs and system state.
*   **Auditability:** Facilitate access to logs and reports for compliance verification.
*   **Accessibility:** The UI itself must adhere to WCAG 2.2 AAA standards (as per `accessibility-policy.md`).

## 2. Key UI Sections & Functionality

### 2.1 Dashboard / Overview

*   **Purpose:** A high-level summary of the Anigma Node's health and current activity.
*   **Elements:**
    *   **System Health Indicators:** Green/Yellow/Red status for core services (Harmonia Daemon, MLX Runtime, Database).
    *   **Active Job Count:** Number of jobs currently in `processing` status.
    *   **Queued Job Count:** Number of jobs awaiting execution.
    *   **Recent Activity Feed:** Scrollable list of the last 10-20 completed or failed jobs, with links to details.
    *   **Resource Utilization (Basic):** CPU, Memory, Disk usage for the Anigma Node.

### 2.2 Job Queue Management

*   **Purpose:** View, filter, and manage all jobs processed by Anigma.
*   **Elements:**
    *   **Job List Table:**
        *   Columns: Job ID, Document Name, Job Type (e.g., "PDF to EPUB," "Summarize," "Braille Conversion"), Status (Pending, In Progress, Completed, Failed, Cancelled), Progress (%), Assigned Node (if clustered), Started At, Completed At, Actions.
        *   Filters: By Status, Job Type, Document Name, Date Range.
        *   Sorting: By Status, Started At, Priority.
    *   **Job Detail View (Clickable from table):**
        *   Full Job ID, Status, Priority, Start/End Times.
        *   Input Document Details: Name, Path, Original Format.
        *   Output Details: Generated Formats (e.g., EPUB, MP3, BRF), Download Links.
        *   Processing Log (raw and structured views).
        *   Governance Log (which policies applied, confirmations required).
        *   **Actions:** Pause, Resume, Cancel, Re-queue (for failed jobs), View Output, Download Output, View Input.
*   **Bulk Actions:** Ability to select multiple jobs and perform actions (e.g., "Cancel Selected," "Re-queue Failed").

### 2.3 MLX Model & Capability Management

*   **Purpose:** Monitor the status of local MLX models and the capabilities of the Anigma Node.
*   **Elements:**
    *   **Installed Models List:**
        *   Columns: Model Name, Version, Type (e.g., "Embedding," "LLM," "Vision," "TTS"), Status (Loaded, Unloaded, Error), Size, Capabilities (e.g., "Summarization," "Sentiment Analysis").
        *   Actions: Load, Unload, Update.
    *   **Capability Overview:** A summary of the AI capabilities currently available on this Anigma Node (e.g., "Summarization," "Alt-Text Generation," "Multi-Voice TTS").
    *   **MLX Runtime Status:** Health of the underlying MLX services.

### 2.4 Governance & Audit Logs

*   **Purpose:** Provide transparent access to governance decisions and detailed audit trails.
*   **Elements:**
    *   **Governance Event Log Table:**
        *   Columns: Event ID, Timestamp, Event Type (e.g., "Write Gate Check," "Playbook Decision," "Kill Switch Activation," "Human Confirmation"), Outcome (Allowed, Denied, Confirmed), Associated Job/Session ID, User.
        *   Filters: By Event Type, Outcome, User, Job/Session ID, Date Range.
        *   **Export Reports:** Options to export compliance reports (e.g., "Documents Converted by Type," "Manual Interventions," "Governance Policy Violations").

### 2.5 System Configuration & Health

*   **Purpose:** Basic settings and advanced diagnostics.
*   **Elements:**
    *   **General Settings:** Node Name, Data Storage Location.
    *   **User Management (Basic):** View active sessions, connected clients.
    *   **Daemon Logs:** Live tail of the Harmonia Daemon logs with configurable verbosity.
    *   **Diagnostics Bundle Export:** One-click export of a redacted diagnostics package for support.

## 3. Interaction & Design Notes

*   **Consistent with Apple HIG:** Follow macOS Human Interface Guidelines for native application feel.
*   **WCAG 2.2 AAA Compliant:** All UI elements, interactions, and content must adhere to the highest accessibility standards.
*   **Role-Based Access (Future):** Initial version may be single-user admin, but design should allow for future role-based permissions.

This Control Center provides the necessary visibility and management for institutional operators, turning the powerful Anigma backend into an accountable and user-friendly product.
