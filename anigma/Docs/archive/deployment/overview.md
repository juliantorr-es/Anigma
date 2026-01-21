# Anigma Deployment Overview: The Anigma Node

Anigma is designed to be deployed as a self-contained **Anigma Node** within an institution's local network. This "node" concept embodies our commitment to local-first processing, data ownership, and robust governance. This document provides a high-level overview of deploying, managing, and maintaining an Anigma Node.

## 1. The Anigma Node Concept

An Anigma Node is a dedicated, on-premises server that hosts the Harmonia AI orchestrator, MLX inference services, and manages all document processing and accessibility workflows. It ensures that sensitive data remains within the institution's control and processing happens locally.

*   **Platform:** Primarily designed for **Apple Silicon Macs** (e.g., Mac mini, Mac Studio, Mac Pro) due to their integrated MLX framework for high-performance, local AI inference.
*   **Scalability:** A single node can serve a department or small institution. Multiple nodes can be clustered (future roadmap item) for larger-scale or distributed deployments.

## 2. Hardware & Software Footprint

### 2.1 Hardware Requirements (Minimum for a Pilot)

*   **Device:** Apple Silicon Mac (M1/M2/M3 chip, Mac mini or better recommended).
*   **RAM:** 16GB unified memory (32GB+ recommended for larger language models or concurrent tasks).
*   **Storage:** 512GB SSD (1TB+ recommended for document archives and local models).
*   **Network:** Stable Gigabit Ethernet connection.

### 2.2 Software Requirements

*   **Operating System:** macOS (latest stable version recommended).
*   **Xcode:** Latest version for Swift compilation.
*   **Node.js & npm:** For managing documentation and tooling.
*   **Swift Runtime:** Included with macOS/Xcode.

## 3. Installation Process (High-Level)

The installation of an Anigma Node involves a guided setup to prepare the macOS environment and deploy the Harmonia daemon.

1.  **Prepare macOS:** Ensure macOS is updated, and necessary developer tools (Xcode, Command Line Tools) are installed.
2.  **Clone Anigma Monorepo:** Obtain the Anigma source code from your designated repository.
3.  **Dependency Setup:** Install Swift and Node.js dependencies.
4.  **Build Harmonia Daemon:** Compile the Harmonia AI orchestrator.
5.  **Initial Configuration:** Configure core settings, including data storage paths and initial policy playbooks.
6.  **Launch Harmonia Daemon:** Start the Harmonia service, ensuring it launches automatically on system restart.

*Detailed installation instructions will be provided in a dedicated "Anigma Node Installation Guide."*

## 4. Updating Anigma Nodes

Managing software updates is critical for security and accessing new features.

*   **Version Control Integration:** Updates will typically involve pulling new code from the Anigma repository.
*   **Automated Updates (Future):** Roadmap includes tools for streamlined, policy-driven updates across multiple nodes.
*   **Migration Management:** Versioned configurations and data migration tools ensure smooth transitions between major releases, preserving existing workflows and data integrity.

## 5. Monitoring & Observability

Ensuring the Anigma Node operates smoothly requires continuous monitoring.

*   **Anigma Control Center (Operator UI):** The primary "pane of glass" for operators to view job queues, MLX model status, system health, and audit logs.
*   **Structured Logs:** Harmonia generates structured logs (JSONL) that can be integrated with institutional logging systems for centralized monitoring and alerting.
*   **Health Check Endpoints:** The Harmonia daemon exposes API endpoints for programmatic health checks and diagnostics.
*   **Diagnostics Bundles:** Tools for generating redacted diagnostics packages to aid in troubleshooting and support.

## 6. Backup & Restore Considerations

Protecting institutional data is paramount.

*   **Node Backup:** Regular macOS backups (e.g., Time Machine, third-party solutions) should be implemented for the entire Anigma Node.
*   **Data Export:** Anigma provides tools to export key operational data (e.g., project configurations, governance policies, audit logs) for off-node backup.
*   **Database Backup:** The internal SQLite database (see Harmonia roadmap Tier 2) should be included in backup routines.

## 7. Security Best Practices

*   **Physical Security:** Ensure the Anigma Node hardware is in a secure physical location.
*   **Network Isolation:** Deploy the Anigma Node on a segmented network, limiting external exposure.
*   **Regular Updates:** Keep macOS and Anigma software updated to mitigate vulnerabilities.

By providing a clear framework for deployment and management, Anigma aims to be a robust, reliable, and easily maintainable solution for institutional AI and accessibility needs.
