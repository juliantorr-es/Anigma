# Anigma Versioning & Release Policy

To ensure stability, predictability, and smooth upgrades for institutional deployments, Anigma adheres to a clear versioning and release policy. This document outlines our approach to version numbers, handling changes, and managing the release cadence.

## 1. Semantic Versioning (SemVer)

Anigma follows [Semantic Versioning 2.0.0](https://semver.org/) (Major.Minor.Patch):

*   **MAJOR version (X.y.z):** Incremented for incompatible API changes, significant architectural shifts, or major new features that break backward compatibility. Requires explicit migration steps.
*   **MINOR version (x.Y.z):** Incremented for new functionality added in a backward-compatible manner, significant feature enhancements, or major performance improvements.
*   **PATCH version (x.y.Z):** Incremented for backward-compatible bug fixes and minor internal changes.

## 2. Breaking Change Policy

Breaking changes are a necessary part of evolving a robust platform. Our policy aims to minimize their impact and provide clear guidance for users.

*   **Communication:** All breaking changes will be clearly documented in the release notes for the MAJOR version. Pre-announcements for upcoming breaking changes will be made in prior MINOR releases.
*   **Deprecation:** Features slated for removal or significant change will be formally deprecated in a MINOR release before their removal in a subsequent MAJOR release, providing a grace period for users to adapt.
*   **Migration Guides:** Every MAJOR version release that introduces breaking changes will be accompanied by a comprehensive migration guide detailing the necessary steps to upgrade.

## 3. Configuration Updates & Migration

Anigma deployments rely on configuration files (e.g., for Playbooks, project settings). Changes to these configurations are managed carefully.

*   **Backward Compatibility:** Minor and Patch releases will strive for backward-compatible configuration changes. New configuration options will have sensible defaults.
*   **Automated vs. Manual Migration:**
    *   **Minor Changes:** Automated configuration migration tools will be provided where feasible to update existing configurations to new formats.
    *   **Major Changes:** For significant configuration overhauls (typically with MAJOR versions), manual review and update may be required, guided by detailed documentation.

## 4. Data Migration Policy

Anigma's internal data structures (e.g., SQLite database schema) will evolve. We have a clear policy for managing these changes.

*   **Schema Versioning:** The internal database schema will be versioned. Harmonia will automatically detect schema versions and apply necessary migrations on startup where possible.
*   **Backward Compatibility:** Efforts will be made to preserve data during schema changes, ensuring existing data remains accessible.
*   **Data Export/Import:** For complex migrations or in cases where data might be restructured, tools for exporting data from older versions and importing into new versions will be provided. Data integrity checks will be a part of the migration process.

## 5. Release Cadence

We aim for a predictable release cadence to allow institutions to plan their upgrade cycles effectively.

*   **MAJOR Releases:** Approximately once per year, for significant new capabilities and architectural updates.
*   **MINOR Releases:** Quarterly, delivering new features and enhancements in a backward-compatible manner.
*   **PATCH Releases:** As needed, for critical bug fixes, security updates, and performance improvements, without introducing new features or breaking changes.

## 6. Pre-Release & Beta Programs

Prior to a public MAJOR or significant MINOR release, Anigma will conduct private beta programs with selected partners to gather feedback and ensure stability. This allows for rigorous testing in diverse environments before general availability.

This versioning and release policy underscores Anigma's commitment to delivering a stable, reliable, and continuously evolving platform that institutions can trust.
